import QtQuick

Canvas {
    id: gl
    property string kind: ""
    property color color: "white"
    width: 18; height: 18
    antialiasing: true
    onKindChanged: requestPaint()
    onColorChanged: requestPaint()
    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        var s = Math.min(width, height) / 18;
        ctx.scale(s, s);
        ctx.strokeStyle = color; ctx.fillStyle = color;
        ctx.lineWidth = 1.5; ctx.lineCap = "round"; ctx.lineJoin = "round";
        var PI = Math.PI;

        function circ(x, y, r) { ctx.beginPath(); ctx.arc(x, y, r, 0, PI * 2); }
        function line(x1, y1, x2, y2) { ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke(); }
        function poly(p, fill) {
            ctx.beginPath(); ctx.moveTo(p[0], p[1]);
            for (var i = 2; i < p.length; i += 2) ctx.lineTo(p[i], p[i + 1]);
            if (fill) { ctx.closePath(); ctx.fill(); } else ctx.stroke();
        }

        if (kind === "power") {
            ctx.beginPath(); ctx.arc(9, 9.6, 6, -PI / 2 + 0.65, -PI / 2 - 0.65 + PI * 2, false); ctx.stroke();
            line(9, 2.2, 9, 8.4);
        } else if (kind === "restart") {
            ctx.beginPath(); ctx.arc(9, 9.8, 5.8, -1.0, 4.4, false); ctx.stroke();
            poly([9.7, 2.7, 6.6, 1.6, 7.8, 5.4], true);
        } else if (kind === "moon") {
            circ(9, 9, 6.8); ctx.fill();
            ctx.globalCompositeOperation = "destination-out";
            circ(12.2, 6.4, 5.6); ctx.fill();
            ctx.globalCompositeOperation = "source-over";
        } else if (kind === "layers") {
            ctx.beginPath(); ctx.moveTo(9, 2.4); ctx.lineTo(15.6, 5.8); ctx.lineTo(9, 9.2); ctx.lineTo(2.4, 5.8); ctx.closePath(); ctx.stroke();
            poly([2.4, 9.2, 9, 12.6, 15.6, 9.2], false);
            poly([2.4, 12.4, 9, 15.8, 15.6, 12.4], false);
        } else if (kind === "chevR") {
            poly([7, 3.5, 12.5, 9, 7, 14.5], false);
        } else if (kind === "lock") {
            ctx.beginPath();
            ctx.moveTo(9, 2.2); ctx.lineTo(15.6, 9.2); ctx.lineTo(12, 9.2); ctx.lineTo(12, 12.4);
            ctx.lineTo(6, 12.4); ctx.lineTo(6, 9.2); ctx.lineTo(2.4, 9.2); ctx.closePath(); ctx.stroke();
            line(6, 15.4, 12, 15.4);
        }
    }
}
