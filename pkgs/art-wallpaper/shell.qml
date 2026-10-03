// Wallpaper + caption for art-wallpaper. Draws on the Background layer of
// every screen, so it replaces hyprpaper rather than sitting on top of it.
// Watches @dir@/current.json and crossfades to each new painting. That dir is
// the art-wallpaper script's cache (art-rotate) or a store path holding the
// pinned painting (art-pinned). Black, with no caption, until a painting loads.
//
// Zoom (on an empty workspace, where the wallpaper gets the pointer): touchpad
// pinch or Ctrl+scroll, drag or two-finger scroll to pan, double-click to
// reset. Past ~1.3x it loads the full-resolution scan (<id>.full.jpg, which
// the script downloads next to the small one) over the small image; ~30 s
// after you are back at 1x it unloads it again, so all day only the small
// image is in memory.
//
// @...@ placeholders are filled by replaceVars in modules/desktop/wallpaper.nix.
import QtQuick
import Quickshell
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

            readonly property real zoom: flick.width > 0 ? flick.contentWidth / flick.width : 1
            property bool wantFull: false

            // Stop at 2 screen pixels per scan pixel; past that it's just blur.
            // Images cover the screen, so the scan's scale at 1x is the larger
            // of the two axis ratios. 10x until the full scan has loaded.
            readonly property real maxZoom: {
                if (full.status !== Image.Ready || flick.width <= 0)
                    return 10;
                const fit = Math.max(flick.width / full.implicitWidth, flick.height / full.implicitHeight);
                const dpr = (screen && screen.devicePixelRatio) || 1;
                return Math.max(2, 2 / (fit * dpr));
            }
            onMaxZoomChanged: if (zoom > maxZoom)
                zoomAt(maxZoom / zoom, Qt.point(flick.width / 2, flick.height / 2))

            onZoomChanged: {
                if (zoom > 1.3) {
                    wantFull = true;
                    unload.stop();
                } else if (zoom < 1.001) {
                    unload.restart();
                }
            }

            function zoomAt(factor, p) {
                const z = Math.max(1, Math.min(maxZoom, zoom * factor));
                if (z === zoom)
                    return;
                // Keep the point under the cursor/fingers fixed on screen.
                flick.resizeContent(flick.width * z, flick.height * z, Qt.point(p.x + flick.contentX, p.y + flick.contentY));
                flick.returnToBounds();
            }

            function cursor() {
                return flick.mapFromItem(hover.parent, hover.point.position);
            }

            function reset() {
                flick.resizeContent(flick.width, flick.height, Qt.point(0, 0));
                flick.contentX = 0;
                flick.contentY = 0;
            }

            Timer {
                id: unload
                interval: 30000
                onTriggered: win.wantFull = false
            }

            Connections {
                target: root
                function onImageChanged() {
                    win.reset();
                    win.wantFull = false;
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

                    // back holds the previous painting while front fades the new one in.
                    Image {
                        id: back
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    Image {
                        id: front
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        source: root.image
                        onSourceChanged: opacity = 0
                        onStatusChanged: if (status === Image.Ready) fade.restart()

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
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        // Scaled well below 1:1 just past 1.3x; mipmaps stop
                        // the fine canvas texture shimmering there.
                        mipmap: true
                        source: win.wantFull ? root.fullImage : ""
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
                anchors {
                    left: parent.left
                    bottom: parent.bottom
                    margins: 32
                }
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
}
