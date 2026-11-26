(function () {
    var source = document.getElementById('tasmota-backlog');
    if (!source || typeof qrcode !== 'function') { return; }

    var text = source.textContent;
    var download = document.getElementById('tasmota-download');
    if (download) {
        download.addEventListener('click', function () {
            var blob = new Blob([text + '\n'], { type: 'text/plain;charset=utf-8' });
            var url = URL.createObjectURL(blob);
            var link = document.createElement('a');
            link.href = url;
            link.download = 'tasmota_config.txt';
            document.body.appendChild(link);
            link.click();
            link.remove();
            URL.revokeObjectURL(url);
        });
    }

    var holder = document.getElementById('tasmota-qr');
    if (holder) {
        var qr = qrcode(0, 'M');
        qr.addData(text);
        qr.make();
        holder.innerHTML = qr.createImgTag(4, 8);
    }
})();
