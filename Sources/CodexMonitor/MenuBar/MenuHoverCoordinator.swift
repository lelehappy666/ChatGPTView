enum MenuHoverDelay: Equatable {
    case statusToPanel
    case panelExit

    var nanoseconds: UInt64 {
        switch self {
        case .statusToPanel:
            350_000_000
        case .panelExit:
            300_000_000
        }
    }
}

enum MenuHoverAction: Equatable {
    case scheduleOpen
    case cancelOpen
    case scheduleClose(delay: MenuHoverDelay)
    case cancelClose
}

struct MenuHoverCoordinator {
    static let openDelayNanoseconds: UInt64 = 120_000_000

    private(set) var isStatusHovered = false
    private(set) var isPanelHovered = false
    private(set) var hasPanelEntered = false

    mutating func statusHoverChanged(
        isInside: Bool,
        isPopoverShown: Bool
    ) -> [MenuHoverAction] {
        guard isInside != isStatusHovered else { return [] }
        isStatusHovered = isInside

        if isInside {
            var actions: [MenuHoverAction] = [.cancelClose]
            if !isPopoverShown {
                actions.append(.scheduleOpen)
            }
            return actions
        }

        var actions: [MenuHoverAction] = [.cancelOpen]
        if isPopoverShown, !isPanelHovered {
            actions.append(.scheduleClose(delay: .statusToPanel))
        }
        return actions
    }

    mutating func panelHoverChanged(
        isInside: Bool,
        isPopoverShown: Bool
    ) -> [MenuHoverAction] {
        guard isInside != isPanelHovered else {
            if !isInside, !hasPanelEntered {
                return []
            }
            return []
        }
        isPanelHovered = isInside

        if isInside {
            hasPanelEntered = true
            return [.cancelClose]
        }

        guard hasPanelEntered, isPopoverShown, !isStatusHovered else {
            return []
        }
        return [.scheduleClose(delay: .panelExit)]
    }

    mutating func popoverDidShow() {
        if isPanelHovered {
            hasPanelEntered = true
        }
    }

    mutating func popoverDidClose() {
        isPanelHovered = false
        hasPanelEntered = false
    }
}
