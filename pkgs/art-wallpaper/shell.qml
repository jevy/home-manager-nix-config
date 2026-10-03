// Wallpaper + caption for art-wallpaper. Draws on the Background layer of
// every screen, so it replaces hyprpaper rather than sitting on top of it.
// Watches @dir@/current.json and crossfades to each new painting. That dir is
// the art-wallpaper script's cache (art-rotate) or a store path holding the
// pinned painting (art-pinned). Black, with no caption, until a painting loads.
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

    FileView {
        path: root.dir + "/current.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.info = JSON.parse(text());
            } catch (e) {
                console.warn("art-wallpaper: bad current.json", e);
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
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

            Rectangle {
                visible: root.info !== null
                anchors {
                    left: parent.left
                    bottom: parent.bottom
                    margins: 32
                }
                width: caption.implicitWidth + 32
                height: caption.implicitHeight + 24
                radius: 8
                color: "#cc@base00@"

                Column {
                    id: caption
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: root.info ? root.info.title : ""
                        color: "#@base05@"
                        font.family: "@serif@"
                        font.italic: true
                        font.pixelSize: 20
                        // Some CMA titles run long; cap the caption width.
                        width: Math.min(implicitWidth, 720)
                        elide: Text.ElideRight
                    }

                    Text {
                        text: root.info ? root.info.artist + (root.info.date ? ", " + root.info.date : "") : ""
                        color: "#@base04@"
                        font.family: "@serif@"
                        font.pixelSize: 14
                    }
                }
            }
        }
    }
}
