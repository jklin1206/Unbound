import SwiftUI
import UIKit

struct ZoomableTreeScrollView<Content: View>: UIViewRepresentable {
    let contentSize: CGSize
    let minZoom: CGFloat
    let maxZoom: CGFloat
    let initialZoom: CGFloat
    let initialOffset: CGPoint?
    @ViewBuilder let content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(minZoom: minZoom, maxZoom: maxZoom)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = minZoom
        scrollView.maximumZoomScale = maxZoom
        scrollView.zoomScale = initialZoom
        // Hard boundaries: no bounce past content edges on any axis.
        // bouncesZoom stays on so pinch overshoot still feels rubbery.
        scrollView.bounces = false
        scrollView.bouncesZoom = true
        scrollView.alwaysBounceHorizontal = false
        scrollView.alwaysBounceVertical = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.decelerationRate = .normal
        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = true
        scrollView.backgroundColor = .clear
        scrollView.clipsToBounds = true

        let host = UIHostingController(rootView: content())
        host.view.backgroundColor = .clear
        host.view.frame = CGRect(origin: .zero, size: contentSize)
        host.view.isUserInteractionEnabled = true
        context.coordinator.hostingController = host

        scrollView.addSubview(host.view)
        scrollView.contentSize = contentSize

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        doubleTap.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(doubleTap)
        context.coordinator.scrollView = scrollView

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        let isInteracting = scrollView.isZooming || scrollView.isDragging || scrollView.isDecelerating
        if !isInteracting {
            context.coordinator.hostingController?.rootView = content()
            if context.coordinator.hostingController?.view.bounds.size != contentSize {
                context.coordinator.hostingController?.view.frame = CGRect(origin: .zero, size: contentSize)
            }
        }
        context.coordinator.minZoom = minZoom
        context.coordinator.maxZoom = maxZoom
        scrollView.minimumZoomScale = minZoom
        scrollView.maximumZoomScale = maxZoom
        scrollView.contentSize = contentSize

        if !context.coordinator.didApplyInitialZoom {
            let zoom = min(max(initialZoom, minZoom), maxZoom)
            scrollView.setZoomScale(zoom, animated: false)
            context.coordinator.didApplyInitialZoom = true
        } else if scrollView.zoomScale < minZoom || scrollView.zoomScale > maxZoom {
            scrollView.setZoomScale(min(max(scrollView.zoomScale, minZoom), maxZoom), animated: false)
        }

        // Apply initial content offset once, after zoom is set, so the
        // active node lands centered in the viewport on open.
        if !context.coordinator.didApplyInitialOffset, let offset = initialOffset {
            // Clamp to valid range against the *current* zoomed content size
            // and viewport bounds, in case sizing changed between layouts.
            let maxOffX = max(0, scrollView.contentSize.width - scrollView.bounds.width)
            let maxOffY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
            let clamped = CGPoint(
                x: min(max(0, offset.x), maxOffX),
                y: min(max(0, offset.y), maxOffY)
            )
            scrollView.setContentOffset(clamped, animated: false)
            context.coordinator.didApplyInitialOffset = true
        }

        context.coordinator.centerContentIfNeeded()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        var hostingController: UIHostingController<Content>?
        weak var scrollView: UIScrollView?
        var minZoom: CGFloat = 0.45
        var maxZoom: CGFloat = 1.5
        var didApplyInitialZoom = false
        var didApplyInitialOffset = false

        init(minZoom: CGFloat, maxZoom: CGFloat) {
            self.minZoom = minZoom
            self.maxZoom = maxZoom
            super.init()
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hostingController?.view
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContentIfNeeded()
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView else { return }
            if scrollView.zoomScale > minZoom + 0.08 {
                scrollView.setZoomScale(minZoom, animated: true)
                return
            }

            let tapPoint = recognizer.location(in: hostingController?.view)
            let targetZoom = min(max(1.0, minZoom), maxZoom)
            let width = scrollView.bounds.width / targetZoom
            let height = scrollView.bounds.height / targetZoom
            let rect = CGRect(
                x: tapPoint.x - width / 2,
                y: tapPoint.y - height / 2,
                width: width,
                height: height
            )
            scrollView.zoom(to: rect, animated: true)
        }

        func centerContentIfNeeded() {
            guard let scrollView, let hostedView = hostingController?.view else { return }
            let boundsSize = scrollView.bounds.size
            var frame = hostedView.frame
            frame.origin.x = frame.size.width < boundsSize.width
                ? (boundsSize.width - frame.size.width) / 2
                : 0
            frame.origin.y = frame.size.height < boundsSize.height
                ? (boundsSize.height - frame.size.height) / 2
                : 0
            hostedView.frame = frame
        }
    }
}
