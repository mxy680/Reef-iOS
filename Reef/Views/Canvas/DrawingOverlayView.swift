//
//  DrawingOverlayView.swift
//  Reef
//
//  PencilKit canvas overlay for document annotation
//

import SwiftUI
import PencilKit
import PDFKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct DrawingOverlayView: UIViewRepresentable {
    let documentURL: URL
    let fileType: Note.FileType
    @Binding var selectedTool: CanvasTool
    @Binding var selectedPenColor: Color
    @Binding var selectedHighlighterColor: Color
    @Binding var penWidth: CGFloat
    @Binding var highlighterWidth: CGFloat
    @Binding var eraserSize: CGFloat
    @Binding var eraserType: EraserType
    var isDarkMode: Bool = false
    var onCanvasReady: (CanvasContainerView) -> Void = { _ in }
    var onUndoStateChanged: (Bool) -> Void = { _ in }
    var onRedoStateChanged: (Bool) -> Void = { _ in }

    func makeUIView(context: Context) -> CanvasContainerView {
        let container = CanvasContainerView(documentURL: documentURL, fileType: fileType, isDarkMode: isDarkMode)
        container.canvasView.delegate = context.coordinator
        context.coordinator.container = container
        context.coordinator.onUndoStateChanged = onUndoStateChanged
        context.coordinator.onRedoStateChanged = onRedoStateChanged

        // Set initial tool after a brief delay to ensure view is ready
        let initialColor = UIColor(selectedPenColor)
        let width = penWidth
        DispatchQueue.main.async {
            container.canvasView.tool = PKInkingTool(.pen, color: initialColor, width: width)
            self.onCanvasReady(container)
        }

        return container
    }

    func updateUIView(_ container: CanvasContainerView, context: Context) {
        updateTool(container.canvasView)
        container.updateDarkMode(isDarkMode)
    }

    private func updateTool(_ canvasView: PKCanvasView) {
        switch selectedTool {
        case .pen:
            // Convert SwiftUI Color to UIColor using explicit RGB to avoid color scheme adaptation
            let uiColor = uiColorFromSwiftUIColor(selectedPenColor)
            canvasView.tool = PKInkingTool(.pen, color: uiColor, width: penWidth)
        case .highlighter:
            let uiColor = UIColor(selectedHighlighterColor).withAlphaComponent(0.3)
            canvasView.tool = PKInkingTool(.marker, color: uiColor, width: highlighterWidth * 3)
        case .eraser:
            switch eraserType {
            case .stroke:
                canvasView.tool = PKEraserTool(.vector)
            case .bitmap:
                canvasView.tool = PKEraserTool(.bitmap, width: eraserSize)
            }
        case .lasso:
            canvasView.tool = PKLassoTool()
        }
    }

    /// Converts SwiftUI Color to UIColor
    /// Since the canvas container has overrideUserInterfaceStyle = .light,
    /// PencilKit won't invert colors and we can use UIColor directly
    private func uiColorFromSwiftUIColor(_ color: Color) -> UIColor {
        return UIColor(color)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        weak var container: CanvasContainerView?
        var onUndoStateChanged: (Bool) -> Void = { _ in }
        var onRedoStateChanged: (Bool) -> Void = { _ in }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            updateUndoRedoState(canvasView)
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            updateUndoRedoState(canvasView)
        }

        private func updateUndoRedoState(_ canvasView: PKCanvasView) {
            DispatchQueue.main.async { [weak self] in
                self?.onUndoStateChanged(canvasView.undoManager?.canUndo ?? false)
                self?.onRedoStateChanged(canvasView.undoManager?.canRedo ?? false)
            }
        }
    }
}

// MARK: - Canvas Container with Zoom and Pan

class CanvasContainerView: UIView {
    let scrollView = UIScrollView()
    let contentView = UIView()  // Container for document + canvas
    let documentImageView = UIImageView()
    let canvasView = ReefCanvasView()

    private var documentURL: URL?
    private var fileType: Note.FileType?
    private var isDarkMode: Bool = false

    /// Light gray background for scroll view in light mode (close to white)
    private static let scrollBackgroundLight = UIColor(red: 245/255, green: 245/255, blue: 245/255, alpha: 1)

    /// Deep Ocean (#0A1628) for document page background in dark mode
    private static let pageBackgroundDark = UIColor(red: 10/255, green: 22/255, blue: 40/255, alpha: 1)

    /// Lighter background for scroll area in dark mode (lighter than the page)
    private static let scrollBackgroundDark = UIColor(red: 18/255, green: 32/255, blue: 52/255, alpha: 1)

    convenience init(documentURL: URL, fileType: Note.FileType, isDarkMode: Bool = false) {
        self.init(frame: .zero)
        self.documentURL = documentURL
        self.fileType = fileType
        self.isDarkMode = isDarkMode
        loadDocument()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        // Configure scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 8.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = self
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = Self.scrollBackgroundLight  // Updated in loadDocument for dark mode
        addSubview(scrollView)

        // Configure content view (holds both document and canvas)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .white
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOpacity = 0.25
        contentView.layer.shadowOffset = CGSize(width: 0, height: 4)
        contentView.layer.shadowRadius = 12
        scrollView.addSubview(contentView)

        // Configure document image view
        documentImageView.translatesAutoresizingMaskIntoConstraints = false
        documentImageView.contentMode = .scaleAspectFit
        documentImageView.backgroundColor = .white
        contentView.addSubview(documentImageView)

        // Configure canvas view (transparent overlay)
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .pencilOnly
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(canvasView)

        // Force light interface style to prevent PencilKit from inverting colors
        // The app manages dark mode appearance manually via ThemeManager
        self.overrideUserInterfaceStyle = .light

        // Layout constraints for scroll view
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),

            // Document and canvas fill the content view
            documentImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            documentImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            documentImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            documentImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            canvasView.topAnchor.constraint(equalTo: contentView.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    func updateDarkMode(_ newDarkMode: Bool) {
        guard newDarkMode != isDarkMode else { return }
        isDarkMode = newDarkMode
        animateThemeChange()
    }

    private func animateThemeChange() {
        guard let url = documentURL, let fileType = fileType else { return }

        let newScrollBg = isDarkMode ? Self.scrollBackgroundDark : Self.scrollBackgroundLight
        let newPageBg: UIColor = isDarkMode ? Self.pageBackgroundDark : .white
        let newShadowColor = isDarkMode ? UIColor(white: 0.4, alpha: 1).cgColor : UIColor.black.cgColor
        let newShadowOpacity: Float = isDarkMode ? 0.3 : 0.25
        let newShadowRadius: CGFloat = isDarkMode ? 16 : 12

        // Animate background colors
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.scrollView.backgroundColor = newScrollBg
            self.contentView.backgroundColor = newPageBg
            self.documentImageView.backgroundColor = newPageBg
        }

        // Animate shadow changes
        let shadowColorAnim = CABasicAnimation(keyPath: "shadowColor")
        shadowColorAnim.fromValue = contentView.layer.shadowColor
        shadowColorAnim.toValue = newShadowColor
        shadowColorAnim.duration = 0.3

        let shadowOpacityAnim = CABasicAnimation(keyPath: "shadowOpacity")
        shadowOpacityAnim.fromValue = contentView.layer.shadowOpacity
        shadowOpacityAnim.toValue = newShadowOpacity
        shadowOpacityAnim.duration = 0.3

        let shadowRadiusAnim = CABasicAnimation(keyPath: "shadowRadius")
        shadowRadiusAnim.fromValue = contentView.layer.shadowRadius
        shadowRadiusAnim.toValue = newShadowRadius
        shadowRadiusAnim.duration = 0.3

        contentView.layer.add(shadowColorAnim, forKey: "shadowColor")
        contentView.layer.add(shadowOpacityAnim, forKey: "shadowOpacity")
        contentView.layer.add(shadowRadiusAnim, forKey: "shadowRadius")

        contentView.layer.shadowColor = newShadowColor
        contentView.layer.shadowOpacity = newShadowOpacity
        contentView.layer.shadowRadius = newShadowRadius

        // Load and crossfade to new document image
        Task { [weak self] in
            let loadedImage: UIImage? = await {
                switch fileType {
                case .pdf:
                    return await self?.renderPDFToImage(url: url)
                case .image:
                    if let data = try? Data(contentsOf: url) {
                        return UIImage(data: data)
                    }
                    return nil
                case .document:
                    return nil
                }
            }()

            await MainActor.run { [weak self] in
                guard let self = self, let image = loadedImage else { return }
                UIView.transition(
                    with: self.documentImageView,
                    duration: 0.3,
                    options: .transitionCrossDissolve
                ) {
                    self.documentImageView.image = image
                }
            }
        }
    }

    private func loadDocument() {
        guard let url = documentURL, let fileType = fileType else { return }

        // Update backgrounds based on dark mode
        scrollView.backgroundColor = isDarkMode ? Self.scrollBackgroundDark : Self.scrollBackgroundLight
        let pageBgColor: UIColor = isDarkMode ? Self.pageBackgroundDark : .white
        contentView.backgroundColor = pageBgColor
        documentImageView.backgroundColor = pageBgColor

        // Adjust shadow for dark mode
        if isDarkMode {
            contentView.layer.shadowColor = UIColor(white: 0.4, alpha: 1).cgColor
            contentView.layer.shadowOpacity = 0.3
            contentView.layer.shadowRadius = 16
        } else {
            contentView.layer.shadowColor = UIColor.black.cgColor
            contentView.layer.shadowOpacity = 0.25
            contentView.layer.shadowRadius = 12
        }

        Task { [weak self] in
            let loadedImage: UIImage? = await {
                switch fileType {
                case .pdf:
                    return await self?.renderPDFToImage(url: url)
                case .image:
                    if let data = try? Data(contentsOf: url) {
                        return UIImage(data: data)
                    }
                    return nil
                case .document:
                    return nil
                }
            }()

            await MainActor.run { [weak self, loadedImage] in
                guard let self = self, let image = loadedImage else { return }
                self.documentImageView.image = image
                self.updateContentSize(for: image.size)
            }
        }
    }

    private func renderPDFToImage(url: URL) async -> UIImage? {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: 0) else { return nil }

        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0  // Retina quality

        let renderer = UIGraphicsImageRenderer(size: CGSize(
            width: pageRect.width * scale,
            height: pageRect.height * scale
        ))

        let normalImage = renderer.image { context in
            // Fill with white background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: renderer.format.bounds.size))

            context.cgContext.translateBy(x: 0, y: pageRect.height * scale)
            context.cgContext.scaleBy(x: scale, y: -scale)

            page.draw(with: .mediaBox, to: context.cgContext)
        }

        // In dark mode, apply false color filter to invert: black text → white, white bg → Deep Ocean
        if isDarkMode {
            return applyDarkModeFilter(to: normalImage)
        }

        return normalImage
    }

    /// Applies false color filter to convert light mode PDF to dark mode
    /// Maps black (text) → white, white (background) → Deep Ocean
    private func applyDarkModeFilter(to image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return image }

        let falseColor = CIFilter.falseColor()
        falseColor.inputImage = ciImage
        // color0: Black pixels (text) → White for readability
        falseColor.color0 = CIColor(red: 1, green: 1, blue: 1)
        // color1: White pixels (background) → Deep Ocean (#0A1628)
        falseColor.color1 = CIColor(red: 10/255, green: 22/255, blue: 40/255)

        guard let outputImage = falseColor.outputImage else { return image }

        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private var contentWidthConstraint: NSLayoutConstraint?
    private var contentHeightConstraint: NSLayoutConstraint?

    private func updateContentSize(for imageSize: CGSize) {
        // Remove old constraints
        contentWidthConstraint?.isActive = false
        contentHeightConstraint?.isActive = false

        // Set content size based on document
        contentWidthConstraint = contentView.widthAnchor.constraint(equalToConstant: imageSize.width)
        contentHeightConstraint = contentView.heightAnchor.constraint(equalToConstant: imageSize.height)

        contentWidthConstraint?.isActive = true
        contentHeightConstraint?.isActive = true

        layoutIfNeeded()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Center content if smaller than scroll view
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
    }
}

// MARK: - UIScrollViewDelegate

extension CanvasContainerView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return contentView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        setNeedsLayout()
    }
}

#Preview {
    DrawingOverlayView(
        documentURL: URL(fileURLWithPath: "/tmp/test.pdf"),
        fileType: .pdf,
        selectedTool: .constant(.pen),
        selectedPenColor: .constant(.black),
        selectedHighlighterColor: .constant(Color(red: 1.0, green: 0.92, blue: 0.23)),
        penWidth: .constant(StrokeWidthRange.penDefault),
        highlighterWidth: .constant(StrokeWidthRange.highlighterDefault),
        eraserSize: .constant(StrokeWidthRange.eraserDefault),
        eraserType: .constant(.stroke)
    )
    .background(Color.gray.opacity(0.2))
}
