import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Item {
    id: root
    width: 1920
    height: 1080
    focus: true
    readonly property real u: Math.max(0.65, height / 1200)

    // current state
    property int selectedUserIndex: (typeof userModel !== "undefined" && userModel.lastIndex >= 0) ? userModel.lastIndex : 0
    property string currentUsername: {
        if (typeof userModel === "undefined" || userModel.count === 0) return "";
        return userModel.data(userModel.index(selectedUserIndex, 0), Qt.UserRole + 1) || userModel.lastUser || "";
    }
    property string currentRealName: {
        if (typeof userModel === "undefined" || userModel.count === 0) return "";
        var rn = userModel.data(userModel.index(selectedUserIndex, 0), Qt.UserRole + 2);
        return (rn && rn.length > 0) ? rn : currentUsername;
    }
    property int selectedSessionIndex: (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0) ? sessionModel.lastIndex : 0
    property string passwordText: passwordInput.text
    property bool isBusy: false
    property string errorMessage: ""
    property bool enterHeld: false
    property var currentTime: new Date()

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.currentTime = new Date()
    }

    // -- backgrop and lg pipeline --
    Item {
        id: scene
        anchors.fill: parent

        Image {
            id: wall
            anchors.fill: parent
            source: {
                var raw = (typeof config !== "undefined" && config.background) ? String(config.background) : "background.jpg";
                var bg = raw.split("#")[0].split(";")[0].trim();
                if (!bg) bg = "background.jpg";
                // if absolute path: load with file://
                if (bg.indexOf("/") === 0) return "file://" + bg;
                return Qt.resolvedUrl(bg);
            }
            fillMode: Image.PreserveAspectCrop
            smooth: true
            asynchronous: false
            onStatusChanged: {
                if (status === Image.Error) {
                    console.log("[MacTahoe] Failed to load wallpaper from:", source);
                }
            }
        }

        // fall back backdrop gradient if there is no background.jpg
        Rectangle {
            anchors.fill: parent
            visible: wall.status !== Image.Ready
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#1e3c72" }
                GradientStop { position: 0.5; color: "#2a5298" }
                GradientStop { position: 1.0; color: "#0f2027" }
            }
        }

        // depth vignette (insp. MacOS)
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.22) }
                GradientStop { position: 0.35; color: Qt.rgba(0, 0, 0, 0.0) }
                GradientStop { position: 0.70; color: Qt.rgba(0, 0, 0, 0.0) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.35) }
            }
        }
    }

    // shared blurred texture used by Glass.qml to refract background
    ShaderEffectSource {
        id: sceneTex
        sourceItem: scene
        visible: false
        live: true
        width: root.width
        height: root.height
        textureSize: Qt.size(Math.max(1, Math.round(root.width / 2)), Math.max(1, Math.round(root.height / 2)))
    }

    MultiEffect {
        id: sceneBlur
        source: sceneTex
        width: sceneTex.textureSize.width
        height: sceneTex.textureSize.height
        blurEnabled: true
        blurMax: 32
        blur: 0.35
        autoPaddingEnabled: false
        visible: false
    }

    ShaderEffectSource {
        id: glassTex
        sourceItem: sceneBlur
        live: true
        mipmap: true
        visible: false
    }

    // -- status bar --
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 18 * root.u
        spacing: 12 * root.u

        // session pick pill
        Item {
            id: sessionPill
            width: sessionRow.implicitWidth + 24 * root.u
            height: 32 * root.u
            visible: typeof sessionModel !== "undefined" && sessionModel.count > 1

            Glass {
                anchors.fill: parent
                src: glassTex
                frame: root
                cornerR: height / 2
                thickness: 18
                tint: 0.22
                dark: false
            }

            Row {
                id: sessionRow
                anchors.centerIn: parent
                spacing: 6 * root.u

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14 * root.u; height: 14 * root.u
                    kind: "layers"
                    color: "white"
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (typeof sessionModel !== "undefined" && sessionModel.count > 0)
                          ? sessionModel.data(sessionModel.index(root.selectedSessionIndex, 0), Qt.UserRole + 1) : "Session"
                    color: "white"
                    font.pixelSize: 12 * root.u
                    font.weight: Font.DemiBold
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: sessionMenu.visible = !sessionMenu.visible
            }

            // session picker dropdown
            Item {
                id: sessionMenu
                visible: false
                y: sessionPill.height + 8 * root.u
                anchors.right: parent.right
                width: 180 * root.u
                height: sessionList.contentHeight + 16 * root.u

                Glass {
                    anchors.fill: parent
                    src: glassTex
                    frame: root
                    cornerR: 14 * root.u
                    thickness: 20
                    tint: 0.35
                    dark: false
                }

                ListView {
                    id: sessionList
                    anchors.fill: parent
                    anchors.margins: 8 * root.u
                    model: sessionModel
                    delegate: Rectangle {
                        width: sessionList.width
                        height: 28 * root.u
                        radius: 6 * root.u
                        color: sMa.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : (index === root.selectedSessionIndex ? Qt.rgba(1, 1, 1, 0.12) : "transparent")

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8 * root.u
                            anchors.verticalCenter: parent.verticalCenter
                            text: model.name || ""
                            color: "white"
                            font.pixelSize: 12 * root.u
                            font.weight: index === root.selectedSessionIndex ? Font.Bold : Font.Normal
                        }

                        MouseArea {
                            id: sMa
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.selectedSessionIndex = index
                                sessionMenu.visible = false
                            }
                        }
                    }
                }
            }
        }

        // pow options (suspend, reboot, poweroff)
        Row {
            spacing: 8 * root.u
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: [
                    { icon: "moon", action: function() { sddm.suspend(); } },
                    { icon: "restart", action: function() { sddm.reboot(); } },
                    { icon: "power", action: function() { sddm.powerOff(); } }
                ]
                delegate: Item {
                    width: 32 * root.u
                    height: 32 * root.u

                    Glass {
                        anchors.fill: parent
                        src: glassTex
                        frame: root
                        cornerR: height / 2
                        thickness: 16
                        tint: 0.22
                        dark: false
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: "white"
                        opacity: btnMa.pressed ? 0.22 : (btnMa.containsMouse ? 0.12 : 0)
                    }

                    Glyph {
                        anchors.centerIn: parent
                        width: 15 * root.u; height: 15 * root.u
                        kind: modelData.icon
                        color: "white"
                    }

                    MouseArea {
                        id: btnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modelData.action()
                    }
                }
            }
        }
    }

    // - tahoe insp. clock (center top-ish) --
    Column {
        id: clockCol
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.08
        spacing: 2 * root.u

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(root.currentTime, "dddd, MMMM d")
            color: Qt.rgba(1, 1, 1, 0.92)
            font.pixelSize: 24 * root.u
            font.weight: Font.DemiBold
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.6; shadowOpacity: 0.35 }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(root.currentTime, "h:mm")
            color: "white"
            font.pixelSize: 130 * root.u
            font.weight: Font.Bold
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.7; shadowOpacity: 0.25; shadowVerticalOffset: 3 }
        }
    }

    // -- actual login area (including avatar & password ofc) --
    Column {
        id: loginCol
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 84 * root.u
        spacing: 12 * root.u

        // avatar
        Item {
            id: avatarContainer
            anchors.horizontalCenter: parent.horizontalCenter
            width: 82 * root.u
            height: width
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Qt.rgba(1, 1, 1, 0.18)

                // placeholder
                Text {
                    anchors.centerIn: parent
                    visible: avatarImg.status !== Image.Ready
                    text: root.currentRealName.length > 0 ? root.currentRealName.charAt(0).toUpperCase() : "?"
                    color: "white"
                    font.pixelSize: 34 * root.u
                    font.weight: Font.DemiBold
                }
            }

            // mask (layer.enabled: true is needed for qt to render it to gpu memory!)
            Item {
                id: avMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                layer.smooth: true

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "black"
                }
            }

            // user avatar image (~/.face.icon -> ~/.face -> AccountsService)
            Image {
                id: avatarImg
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: false
                cache: false
                smooth: true
                mipmap: true
                visible: status === Image.Ready

                source: {
                    if (!root.currentUsername) return "";
                    return "file:///home/" + root.currentUsername + "/.face.icon";
                }

                onStatusChanged: {
                    if (status === Image.Error) {
                        if (source.toString().indexOf(".face.icon") >= 0) {
                            source = "file:///home/" + root.currentUsername + "/.face";
                        } else if (source.toString().indexOf(".face") >= 0 && source.toString().indexOf(".face.icon") < 0) {
                            source = "file:///var/lib/AccountsService/icons/" + root.currentUsername;
                        }
                    }
                }

                Connections {
                    target: root
                    function onCurrentUsernameChanged() {
                        avatarImg.source = "file:///home/" + root.currentUsername + "/.face.icon";
                    }
                }

                layer.enabled: status === Image.Ready
                layer.smooth: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: avMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }
            }

            // outer glass
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 1.5
                border.color: Qt.rgba(1, 1, 1, 0.32)
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: typeof userModel !== "undefined" && userModel.count > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (typeof userModel !== "undefined" && userModel.count > 1) {
                        userSwitcher.visible = !userSwitcher.visible;
                    }
                }
            }
        }

        // username display
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: nameRow.implicitWidth
            height: nameRow.implicitHeight

            Row {
                id: nameRow
                anchors.centerIn: parent
                spacing: 6 * root.u

                Text {
                    text: root.currentRealName
                    color: "white"
                    font.pixelSize: 16 * root.u
                    font.weight: Font.DemiBold
                    layer.enabled: true
                    layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.4; shadowOpacity: 0.3 }
                }

                Glyph {
                    visible: typeof userModel !== "undefined" && userModel.count > 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10 * root.u; height: 10 * root.u
                    kind: "chevR"
                    rotation: 90
                    color: Qt.rgba(1, 1, 1, 0.7)
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: typeof userModel !== "undefined" && userModel.count > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (typeof userModel !== "undefined" && userModel.count > 1) {
                        userSwitcher.visible = !userSwitcher.visible;
                    }
                }
            }
        }

        // -- password entry pill box --
        Item {
            id: pwBox
            anchors.horizontalCenter: parent.horizontalCenter
            width: (root.passwordText.length > 0 ? 240 : 210) * root.u
            height: 38 * root.u
            Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }

            readonly property bool isPressed: pwMa.pressed || root.enterHeld

            transform: [
                Translate { id: shakeT; x: 0 },
                Scale {
                    origin.x: pwBox.width / 2
                    origin.y: pwBox.height / 2
                    xScale: pwBox.isPressed ? 1.04 : 1.0
                    yScale: pwBox.isPressed ? 0.88 : 1.0
                    Behavior on xScale { NumberAnimation { duration: pwBox.isPressed ? 120 : 380; easing.type: Easing.OutQuint } }
                    Behavior on yScale { NumberAnimation { duration: pwBox.isPressed ? 120 : 380; easing.type: Easing.OutQuint } }
                }
            ]

            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: shakeT; property: "x"; to: -16 * root.u; duration: 50; easing.type: Easing.OutQuad }
                NumberAnimation { target: shakeT; property: "x"; to: 14 * root.u; duration: 65; easing.type: Easing.InOutQuad }
                NumberAnimation { target: shakeT; property: "x"; to: -10 * root.u; duration: 60; easing.type: Easing.InOutQuad }
                NumberAnimation { target: shakeT; property: "x"; to: 6 * root.u; duration: 55; easing.type: Easing.InOutQuad }
                NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 80; easing.type: Easing.OutQuint }
            }

            Glass {
                anchors.fill: parent
                src: glassTex
                frame: root
                cornerR: height / 2
                thickness: 22
                tint: 0.25
                dark: false
                shadowAmt: 0.35
            }

            ContourGlow {
                cornerR: pwBox.height / 2
                hovered: pwMa.containsMouse || pwBox.isPressed || passwordInput.activeFocus
                boost: pwBox.isPressed ? 1.5 : 1.0
                at: Qt.point(pwMa.mouseX, pwMa.mouseY)
                glowColor: "white"
            }

            // placeholder
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16 * root.u
                anchors.verticalCenter: parent.verticalCenter
                text: "Enter Password"
                color: Qt.rgba(1, 1, 1, 0.55)
                font.pixelSize: 13 * root.u
                opacity: root.passwordText.length === 0 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            // dots &  cursor container
            // clips & shifts left when passwords get long

            Item {
                id: dotContainer
                anchors.left: parent.left
                anchors.leftMargin: 16 * root.u
                anchors.right: goBtn.visible ? goBtn.left : (capsIcon.visible ? capsIcon.left : parent.right)
                anchors.rightMargin: 8 * root.u
                anchors.verticalCenter: parent.verticalCenter
                height: 18 * root.u
                clip: true

                Item {
                    id: dotScrollItem
                    height: parent.height
                    width: dotRow.width + (cursorBar.visible ? 8 * root.u : 0)
                    // Slide left when dots reach the right edge of the pill
                    x: Math.min(0, dotContainer.width - width)
                    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    Row {
                        id: dotRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6 * root.u

                        Repeater {
                            model: root.passwordText.length
                            delegate: Rectangle {
                                width: 7 * root.u
                                height: width
                                radius: width / 2
                                color: "white"
                                Component.onCompleted: growAnim.start()
                                NumberAnimation on scale {
                                    id: growAnim
                                    from: 0.2; to: 1.0; duration: 140; easing.type: Easing.OutBack
                                }
                            }
                        }
                    }

                    // tahoe cursor bar
                    Rectangle {
                        id: cursorBar
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: dotRow.right
                        anchors.leftMargin: dotRow.width > 0 ? 4 * root.u : 0
                        width: 2 * root.u
                        height: 15 * root.u
                        radius: 1 * root.u
                        color: "white"
                        // sows when typing and focused
                        visible: passwordInput.activeFocus && root.passwordText.length > 0 && !root.isBusy

                        SequentialAnimation on opacity {
                            running: cursorBar.visible
                            loops: Animation.Infinite
                            NumberAnimation { from: 1; to: 1; duration: 500 }
                            NumberAnimation { from: 0; to: 0; duration: 450 }
                        }
                    }
                }
            }

            // kb input handler (built-in caret fully disabled)
            TextInput {
                id: passwordInput
                anchors.fill: parent
                color: "transparent"
                // suppresses qt thin misaligned caret
                cursorDelegate: Component { Item {} } 
                cursorVisible: false
                focus: true
                onTextChanged: root.errorMessage = ""
                onAccepted: root.submitLogin()
            }

            // caps indicator
            Item {
                id: capsIcon
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: goBtn.left
                anchors.rightMargin: 8 * root.u
                width: 16 * root.u; height: width
                visible: (typeof keyboard !== "undefined" && keyboard.capsLock)
                Glyph {
                    anchors.fill: parent
                    kind: "lock"
                    color: "white"
                }
            }

            // submit and spinner
            Item {
                id: goBtn
                anchors.right: parent.right
                anchors.rightMargin: 6 * root.u
                anchors.verticalCenter: parent.verticalCenter
                width: 26 * root.u
                height: width
                visible: root.passwordText.length > 0 || root.isBusy

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.rgba(1, 1, 1, submitMa.pressed ? 0.40 : 0.25)
                    visible: !root.isBusy
                }

                Canvas {
                    anchors.fill: parent
                    visible: !root.isBusy
                    onPaint: {
                        var c = getContext("2d"); c.reset();
                        var w = width;
                        c.strokeStyle = "white"; c.lineWidth = 1.6; c.lineCap = "round"; c.lineJoin = "round";
                        c.beginPath(); c.moveTo(w * 0.32, w * 0.5); c.lineTo(w * 0.68, w * 0.5); c.stroke();
                        c.beginPath(); c.moveTo(w * 0.50, w * 0.32); c.lineTo(w * 0.68, w * 0.5); c.lineTo(w * 0.50, w * 0.68); c.stroke();
                    }
                }

                Canvas {
                    anchors.fill: parent
                    visible: root.isBusy
                    onPaint: {
                        var c = getContext("2d"); c.reset();
                        c.strokeStyle = "white"; c.lineWidth = 1.8; c.lineCap = "round";
                        c.beginPath(); c.arc(width / 2, height / 2, width * 0.36, 0, Math.PI * 1.4); c.stroke();
                    }
                    RotationAnimator on rotation { from: 0; to: 360; duration: 800; loops: Animation.Infinite; running: root.isBusy }
                }

                MouseArea {
                    id: submitMa
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.submitLogin()
                }
            }

            MouseArea {
                id: pwMa
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                hoverEnabled: true
                onClicked: passwordInput.forceActiveFocus()
            }
        }
        
        // subtitle / error
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.errorMessage.length > 0 ? root.errorMessage : "Enter your password to log in"
            color: root.errorMessage.length > 0 ? "#ff6961" : Qt.rgba(1, 1, 1, 0.6)
            font.pixelSize: 12 * root.u
        }
    }

    // user switch popup
    Item {
        id: userSwitcher
        visible: false
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: loginCol.top
        anchors.bottomMargin: 16 * root.u
        width: 240 * root.u
        height: Math.min(320 * root.u, userList.contentHeight + 20 * root.u)

        Glass {
            anchors.fill: parent
            src: glassTex
            frame: root
            cornerR: 18 * root.u
            thickness: 24
            tint: 0.32
            dark: false
        }

        ListView {
            id: userList
            anchors.fill: parent
            anchors.margins: 10 * root.u
            model: userModel
            clip: true
            delegate: Rectangle {
                width: userList.width
                height: 44 * root.u
                radius: 10 * root.u
                color: uMa.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : (index === root.selectedUserIndex ? Qt.rgba(1, 1, 1, 0.10) : "transparent")

                Row {
                    anchors.fill: parent
                    anchors.margins: 6 * root.u
                    spacing: 10 * root.u

                    Rectangle {
                        width: 32 * root.u
                        height: width
                        radius: width / 2
                        color: Qt.rgba(1, 1, 1, 0.22)
                        Text {
                            anchors.centerIn: parent
                            text: (model.realName || model.name || "?").charAt(0).toUpperCase()
                            color: "white"
                            font.pixelSize: 14 * root.u
                            font.weight: Font.Bold
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: model.realName || model.name || ""
                            color: "white"
                            font.pixelSize: 13 * root.u
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: model.name || ""
                            color: Qt.rgba(1, 1, 1, 0.6)
                            font.pixelSize: 11 * root.u
                        }
                    }
                }

                MouseArea {
                    id: uMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        root.selectedUserIndex = index
                        passwordInput.text = ""
                        userSwitcher.visible = false
                        passwordInput.forceActiveFocus()
                    }
                }
            }
        }
    }

    // -- ssdm authentication --
    function submitLogin() {
        if (root.isBusy || root.passwordText.length === 0) return;
        root.isBusy = true;
        root.errorMessage = "";
        sddm.login(root.currentUsername, root.passwordText, root.selectedSessionIndex);
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.isBusy = false;
            passwordInput.text = "";
            root.errorMessage = "Incorrect password";
            shakeAnim.restart();
            passwordInput.forceActiveFocus();
        }
        function onLoginSucceeded() {
            root.isBusy = false;
        }
    }

    // catch mouse clicks anywhere to retain focus
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: passwordInput.forceActiveFocus()
    }

    Keys.onReleased: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.enterHeld = false;
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.enterHeld = true;
            root.submitLogin();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            userSwitcher.visible = false;
            passwordInput.text = "";
            event.accepted = true;
        } else {
            if (!passwordInput.activeFocus) {
                passwordInput.forceActiveFocus();
            }
        }
    }

    Component.onCompleted: passwordInput.forceActiveFocus()
}
