// Wallpaper + caption for art-wallpaper. Draws on the Background layer of
// every screen, so it replaces hyprpaper rather than sitting on top of it.
// Watches @dir@/current.json and crossfades to each new painting. That dir is
// the art-wallpaper script's cache (art-rotate) or a store path holding the
// pinned painting (art-pinned). Black, with no caption, until a painting loads.
//
// Zoom (on an empty workspace, where the wallpaper gets the pointer): touchpad
// pinch or Ctrl+scroll, drag or two-finger scroll to pan, double-click to
// reset. Cropped parts are scrollable at 1x too. Once the small image would
// be drawn bigger than it is (zooming in, or a wide painting filling the
// ultrawide) it loads the full-resolution scan (<id>.full.jpg, which the
// script downloads next to the small one) over it; ~30 s after that stops it
// unloads again, so otherwise only the small image is in memory. Screens
// whose shape would hide over half the painting hang it on a wall instead.
//
// @...@ placeholders are filled by replaceVars in modules/desktop/wallpaper.nix.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property string dir: "@dir@"
    property var info: null
    readonly property string image: info ? "file://" + dir + "/" + info.file : ""
    readonly property string fullImage: info && info.full ? "file://" + dir + "/" + info.full : ""

    FileView {
        id: meta
        path: root.dir + "/current.json"
        watchChanges: true
        onFileChanged: reload()
        // watchChanges only follows a file that exists, so on a first run
        // (empty cache) poll until art-wallpaper writes it.
        onLoadFailed: retry.start()
        onLoaded: {
            try {
                root.info = JSON.parse(text());
            } catch (e) {
                console.warn("art-wallpaper: bad current.json", e);
            }
        }
    }

    // `quickshell ipc call wallpaper zoom 3` / `... reset`: keyboard or script
    // access to the same zoom, centred on each screen.
    signal zoomRequested(real factor)
    signal resetRequested

    IpcHandler {
        target: "wallpaper"
        function zoom(factor: real): void {
            root.zoomRequested(factor);
        }
        function reset(): void {
            root.resetRequested();
        }
    }

    Timer {
        id: retry
        interval: 5000
        onTriggered: meta.reload()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "art-wallpaper"
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "black"

            // Load the full scan whenever the small image would be drawn
            // bigger than it is (zoomed in, or filling the 5120px ultrawide
            // with a wide painting), so nothing is ever upscaled. Kept for
            // 30 s after it stops being needed, to avoid reloading while you
            // zoom in and out.
            readonly property bool needFull: outputScale > 0 && front.sourceSize.width > 0 && front.paintedWidth * outputScale > front.sourceSize.width * 1.1
            // Real output pixels per logical pixel. Qt's devicePixelRatio
            // says 2 on the 1.5x laptop (it draws at 2x and Hyprland scales
            // down), which would load the full scan there all day. 0 until
            // Hyprland's IPC answers, and needFull waits for it.
            readonly property real outputScale: {
                const m = Hyprland.monitorFor(screen);
                return m && m.scale > 0 ? m.scale : 0;
            }
            property bool holdFull: false
            onNeedFullChanged: {
                if (needFull) {
                    holdFull = true;
                    unload.stop();
                } else {
                    unload.restart();
                }
            }

            // Two layouts per screen:
            //   fill: the painting covers the screen. The part that doesn't
            //     fit is scrollable even at 1x (drag or two-finger scroll),
            //     starting centred.
            //   wall: when filling would hide more than half the painting
            //     (a 4:3 painting on the 32:9 ultrawide hides 63%, and the
            //     small image got stretched 1.5x), hang it whole on a wall
            //     with a margin and shadow. Zooming in from there gets you
            //     back to cropped-and-scrollable.
            readonly property real paintingAspect: front.sourceSize.height > 0 ? front.sourceSize.width / front.sourceSize.height : 0
            readonly property bool wall: {
                if (paintingAspect <= 0 || flick.height <= 0)
                    return false;
                const screenAspect = flick.width / flick.height;
                return Math.min(paintingAspect, screenAspect) / Math.max(paintingAspect, screenAspect) < 0.5;
            }
            // Content size at 1x: the screen on the wall; in fill mode the
            // painting at the scale that just covers the screen, so content
            // has the painting's shape and the overflow can be scrolled.
            readonly property real baseW: wall || paintingAspect <= 0 ? flick.width : Math.max(flick.width, flick.height * paintingAspect)
            readonly property real baseH: wall || paintingAspect <= 0 ? flick.height : Math.max(flick.height, flick.width / paintingAspect)
            onBaseWChanged: reset()
            onBaseHChanged: reset()
            readonly property real zoom: baseW > 0 ? flick.contentWidth / baseW : 1
            // Muted colour from the painting (art-wallpaper's `wall`).
            readonly property color wallColour: root.info && root.info.wall ? root.info.wall : "#@base00@"
            readonly property real wallMargin: flick.height * 0.08
            // The painting's rectangle on screen at 1x, for the wall label.
            readonly property real paintRight: (flick.width + front.paintedWidth / zoom) / 2
            readonly property real paintBottom: (flick.height + front.paintedHeight / zoom) / 2

            // Stop at 2 screen pixels per scan pixel; past that it's just blur.
            // Filling the screen, the scan's scale at 1x is content width over
            // scan width; on the wall it's the smaller axis ratio inside the
            // margin. 10x until the full scan has loaded.
            readonly property real maxZoom: {
                if (full.status !== Image.Ready || flick.width <= 0)
                    return 10;
                const fit = wall ? Math.min((flick.width - 2 * wallMargin) / full.implicitWidth, (flick.height - 2 * wallMargin) / full.implicitHeight) : baseW / full.implicitWidth;
                return Math.max(2, 2 / (fit * (outputScale || 1)));
            }
            onMaxZoomChanged: if (zoom > maxZoom)
                zoomAt(maxZoom / zoom, Qt.point(flick.width / 2, flick.height / 2))

            function zoomAt(factor, p) {
                const z = Math.max(1, Math.min(maxZoom, zoom * factor));
                if (z === zoom)
                    return;
                // Keep the point under the cursor/fingers fixed on screen.
                flick.resizeContent(baseW * z, baseH * z, Qt.point(p.x + flick.contentX, p.y + flick.contentY));
                flick.returnToBounds();
            }

            function cursor() {
                return flick.mapFromItem(hover.parent, hover.point.position);
            }

            function reset() {
                flick.resizeContent(baseW, baseH, Qt.point(0, 0));
                // Start centred on the painting; the overflow is scrollable.
                flick.contentX = (baseW - flick.width) / 2;
                flick.contentY = (baseH - flick.height) / 2;
            }

            Timer {
                id: unload
                interval: 30000
                onTriggered: win.holdFull = false
            }

            Connections {
                target: root
                function onImageChanged() {
                    win.reset();
                    win.holdFull = false;
                }
                function onZoomRequested(factor) {
                    win.zoomAt(factor, Qt.point(flick.width / 2, flick.height / 2));
                }
                function onResetRequested() {
                    win.reset();
                }
            }

            Flickable {
                id: flick
                anchors.fill: parent
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: width
                contentHeight: height
                onWidthChanged: win.reset()
                onHeightChanged: win.reset()

                // Zoom around the mouse cursor. A touchpad pinch's centroid
                // doesn't follow the pointer, so track it separately.
                // Handlers declared in a Flickable attach to its moving
                // contentItem, so point.position is in content coordinates;
                // cursor() maps it back to the view.
                HoverHandler {
                    id: hover
                }

                WheelHandler {
                    acceptedModifiers: Qt.ControlModifier
                    onWheel: event => win.zoomAt(Math.pow(1.0015, event.angleDelta.y), win.cursor())
                }

                PinchHandler {
                    target: null
                    onScaleChanged: delta => win.zoomAt(delta, win.cursor())
                }

                TapHandler {
                    onDoubleTapped: win.reset()
                }

                Item {
                    width: flick.contentWidth
                    height: flick.contentHeight

                    Rectangle {
                        anchors.fill: parent
                        visible: win.wall
                        color: win.wallColour
                        Behavior on color {
                            ColorAnimation {
                                duration: 1500
                            }
                        }
                    }

                    // Everything below scales with the content, so the
                    // margin and shadow zoom along with the painting.
                    Item {
                        id: frame
                        anchors.fill: parent
                        anchors.margins: win.wall ? win.wallMargin * win.zoom : 0

                        RectangularShadow {
                            visible: win.wall && front.status === Image.Ready
                            anchors.centerIn: parent
                            width: front.paintedWidth
                            height: front.paintedHeight
                            blur: 48
                            offset: Qt.vector2d(0, 14)
                            color: "#a0000000"
                        }

                        // back holds the previous painting while front fades the new one in.
                        Image {
                            id: back
                            anchors.fill: parent
                            fillMode: win.wall ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        Image {
                            id: front
                            anchors.fill: parent
                            fillMode: win.wall ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                            asynchronous: true
                            source: root.image
                            onSourceChanged: opacity = 0
                            onStatusChanged: if (status === Image.Ready)
                                fade.restart()

                            NumberAnimation {
                                id: fade
                                target: front
                                property: "opacity"
                                to: 1
                                duration: 1500
                                easing.type: Easing.InOutQuad
                                onFinished: back.source = front.source
                            }
                        }

                        // Full-resolution scan, only while zoomed. Same crop as
                        // front, so it lands exactly on top and just sharpens.
                        Image {
                            id: full
                            anchors.fill: parent
                            fillMode: win.wall ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                            asynchronous: true
                            // Often drawn well below 1:1 when it loads; mipmaps stop
                            // the fine canvas texture shimmering there.
                            mipmap: true
                            source: win.needFull || win.holdFull ? root.fullImage : ""
                            // Qt's pixmap cache would keep the decoded scan
                            // after unload; skip it so unloading frees memory.
                            cache: false
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 400
                                }
                            }
                        }
                    }
                }
            }

            // Caption bubble. Hover it and it grows into a panel with the
            // museum's text and the AI commentary (art-wallpaper writes both
            // into current.json); move away and it shrinks back.
            //
            // Type, set like a museum wall label: Cormorant Garamond (upright)
            // for the title and the "did you know" pull quote, Source Serif 4
            // for reading, Inter in spaced capitals for metadata and section
            // labels. Fonts come from desktop/wallpaper.nix.
            Rectangle {
                id: bubble
                // Structured guide from art-wallpaper (hook, why, find,
                // deeper). Older paintings may only have `commentary`.
                readonly property var guide: root.info && root.info.guide ? root.info.guide : null
                readonly property bool hasMore: !!(root.info && (guide || root.info.did_you_know || root.info.description || root.info.commentary))
                property bool open: false
                // Second layer ("More"): the long AI write-up and the
                // museum's own words. Hidden by default to keep it scannable.
                property bool deep: false
                // Ticked "find it" items for the current painting.
                property var found: [false, false, false]

                function esc(t) {
                    return String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
                }

                Connections {
                    target: root
                    function onImageChanged() {
                        bubble.found = [false, false, false];
                        bubble.deep = false;
                    }
                }
                // Fixed open width (a ~70 character measure for the body),
                // so text doesn't reflow while the bubble grows.
                readonly property real openWidth: Math.min(660, win.width - 64)
                property real pad: open ? 24 : 16

                visible: root.info !== null && opacity > 0
                // Out of the way while exploring.
                opacity: win.zoom > 1.01 ? 0 : 1
                Behavior on opacity {
                    NumberAnimation {
                        duration: 300
                    }
                }
                // On the wall it sits beside the painting's lower right like
                // a museum label, if there's room for the open panel; else
                // (and when filling the screen) in the bottom-left corner.
                // Grows upward either way.
                readonly property bool asLabel: win.wall && flick.width - win.paintRight >= openWidth + 80
                x: asLabel ? win.paintRight + 40 : 32
                y: (asLabel ? win.paintBottom : win.height - 32) - height
                width: open ? openWidth : caption.implicitWidth + 2 * pad
                height: open ? Math.min(win.height * 0.72, caption.implicitHeight + more.contentHeight + 3 * pad + 4) : caption.implicitHeight + 24
                radius: open ? 14 : 8
                color: open ? "#f2@base00@" : "#cc@base00@"
                clip: true

                Behavior on width {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on radius {
                    NumberAnimation {
                        duration: 300
                    }
                }
                Behavior on pad {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 300
                    }
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) {
                            shrink.stop();
                            bubble.open = bubble.hasMore;
                        } else {
                            shrink.restart();
                        }
                    }
                }

                // Grace period, so brushing the edge doesn't snap it shut.
                Timer {
                    id: shrink
                    interval: 350
                    onTriggered: {
                        bubble.open = false;
                        bubble.deep = false;
                    }
                }

                Column {
                    id: caption
                    x: bubble.pad
                    y: bubble.open ? 20 : 12
                    spacing: 5
                    Behavior on y {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                    }

                    Text {
                        text: root.info ? root.info.title : ""
                        color: "#@base06@"
                        font.family: "Cormorant Garamond"
                        font.weight: Font.Medium
                        font.pixelSize: 30
                        // Long CMA titles: one elided line when closed, wrap when open.
                        width: bubble.open ? bubble.openWidth - 48 : Math.min(implicitWidth, 720)
                        wrapMode: bubble.open ? Text.WordWrap : Text.NoWrap
                        elide: bubble.open ? Text.ElideNone : Text.ElideRight
                        lineHeight: 0.95
                    }

                    Text {
                        text: root.info ? [root.info.artist, root.info.date, root.info.size].filter(x => x).join("  ·  ") : ""
                        color: "#@base04@"
                        font.family: "Inter"
                        font.weight: Font.Medium
                        font.pixelSize: 13
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.4
                    }
                }

                Flickable {
                    id: more
                    x: 24
                    y: caption.y + caption.implicitHeight + 22
                    width: bubble.openWidth - 48
                    height: bubble.height - y - 24
                    contentHeight: moreText.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    opacity: bubble.open ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 240
                        }
                    }

                    Column {
                        id: moreText
                        width: more.width
                        spacing: 10

                        // Layer 1, the guide: hook, why it matters, find it.
                        Text {
                            visible: bubble.guide !== null
                            text: bubble.guide ? bubble.guide.hook : ""
                            width: parent.width
                            wrapMode: Text.WordWrap
                            color: "#@base06@"
                            font.family: "Source Serif 4"
                            font.weight: Font.Medium
                            font.pixelSize: 21
                            lineHeight: 1.25
                            bottomPadding: 10
                        }

                        Label {
                            visible: bubble.guide !== null
                            text: "Why it matters"
                        }
                        Repeater {
                            model: bubble.guide ? bubble.guide.why : []

                            Body {
                                required property var modelData
                                textFormat: Text.StyledText
                                text: "<b>" + bubble.esc(modelData.lead) + "</b>  " + bubble.esc(modelData.text)
                                leftPadding: 16

                                Rectangle {
                                    x: 3
                                    y: 10
                                    width: 5
                                    height: 5
                                    radius: 2.5
                                    color: "#@base04@"
                                }
                            }
                        }

                        Label {
                            visible: bubble.guide !== null
                            text: "Find it  ·  zoom in"
                            topPadding: 10
                        }
                        Repeater {
                            model: bubble.guide ? bubble.guide.find : []

                            // Click to tick it off once you've found it.
                            Item {
                                id: findItem
                                required property var modelData
                                required property int index
                                readonly property bool done: bubble.found[index] === true
                                width: moreText.width
                                height: findText.implicitHeight

                                Rectangle {
                                    y: 4
                                    width: 16
                                    height: 16
                                    radius: 4
                                    border.width: 1.5
                                    border.color: findItem.done ? "#@base0B@" : "#@base04@"
                                    color: findItem.done ? "#55@base0B@" : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        visible: findItem.done
                                        text: "✓"
                                        color: "#@base06@"
                                        font.pixelSize: 12
                                    }
                                }

                                Body {
                                    id: findText
                                    x: 28
                                    width: parent.width - 28
                                    text: findItem.modelData
                                    color: findItem.done ? "#@base04@" : "#@base05@"
                                    font.strikeout: findItem.done
                                }

                                TapHandler {
                                    onTapped: {
                                        const f = bubble.found.slice();
                                        f[findItem.index] = !f[findItem.index];
                                        bubble.found = f;
                                    }
                                }
                                HoverHandler {
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                        }

                        Text {
                            visible: bubble.guide !== null
                            text: bubble.deep ? "Less  ▴" : "More  ▸"
                            color: "#@base05@"
                            font.family: "Inter"
                            font.weight: Font.DemiBold
                            font.pixelSize: 12
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 1.6
                            topPadding: 12

                            TapHandler {
                                onTapped: bubble.deep = !bubble.deep
                            }
                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }
                        }

                        // Layer 2: under "More", or straight away when a
                        // painting has no guide (no key, or fetched earlier).
                        Column {
                            visible: bubble.guide === null || bubble.deep
                            width: parent.width
                            spacing: 10
                            topPadding: 8

                            Label {
                                visible: deeper.visible
                                text: "Going deeper  ·  AI"
                            }
                            Body {
                                id: deeper
                                visible: text !== ""
                                text: bubble.guide ? bubble.guide.deeper : (root.info && root.info.commentary ? root.info.commentary : "")
                                textFormat: Text.MarkdownText
                                bottomPadding: 8
                            }

                            Label {
                                visible: didYouKnow.visible || museum.visible
                                text: "In the museum's words"
                            }
                            Text {
                                id: didYouKnow
                                visible: text !== ""
                                text: root.info && root.info.did_you_know ? root.info.did_you_know : ""
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: "#@base06@"
                                font.family: "Cormorant Garamond"
                                font.weight: Font.Medium
                                font.pixelSize: 23
                                lineHeight: 1.1
                                bottomPadding: 4
                            }
                            Body {
                                id: museum
                                visible: text !== ""
                                text: root.info && root.info.description ? root.info.description : ""
                            }
                        }

                        Text {
                            visible: !!(root.info && (root.info.guide || root.info.commentary))
                            text: "Guide written by AI (" + (root.info && (root.info.guideModel || root.info.commentaryModel) || "unknown model") + "). It can get details wrong."
                            width: parent.width
                            wrapMode: Text.WordWrap
                            color: "#@base03@"
                            font.family: "Inter"
                            font.pixelSize: 12
                            topPadding: 10
                        }
                    }
                }
            }
        }
    }

    component Label: Text {
        width: parent.width
        color: "#@base04@"
        font.family: "Inter"
        font.weight: Font.DemiBold
        font.pixelSize: 12
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1.6
        bottomPadding: -4
    }

    component Body: Text {
        width: parent.width
        wrapMode: Text.WordWrap
        color: "#@base05@"
        font.family: "Source Serif 4"
        font.pixelSize: 17
        lineHeight: 1.35
    }
}
