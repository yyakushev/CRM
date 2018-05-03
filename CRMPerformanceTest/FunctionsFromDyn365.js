#
# FunctionsFromDyn365.js
#

function runLatencyTest(testId) {
    var trialsToRun = 20,
        results = runDownloadTest("/_static/Tools/Diagnostics/smallfile.txt", trialsToRun),
        testResults = results.testResults,
        txt = "=== Latency Test Info === \r\n";
    txt += "Number of times run: " + trialsToRun + "\r\n";
    for (var avgDownloadTime = 0,
        i = 0; i < testResults.length; i++) {
        txt += "Run " + (i + 1) + " time: " + testResults[i].downloadTime + " ms\r\n";
        avgDownloadTime += testResults[i].downloadTime
    }
    avgDownloadTime = Math.floor(avgDownloadTime / testResults.length);
    txt += "Average latency: " + avgDownloadTime + " ms\r\n";
    appendToResultConsole(txt);
    return avgDownloadTime + " ms"
}
function runBandwidthTest(testId) {
    for (var trialsToRun = 10,
        adaptionSchedule = [{ speed: 0, url: "/_static/Tools/Diagnostics/random100x100.jpg" }, { speed: .5, url: "/_static/Tools/Diagnostics/random350x350.jpg" }, { speed: 1, url: "/_static/Tools/Diagnostics/random750x750.jpg" }, { speed: 2, url: "/_static/Tools/Diagnostics/random1000x1000.jpg" }, { speed: 4, url: "/_static/Tools/Diagnostics/random1500x1500.jpg" }],
        results = runDownloadTest(adaptionSchedule, trialsToRun),
        testResults = results.testResults,
        txt = "=== Bandwidth Test Info === \r\n",
        i = 0; i < testResults.length; i++) {
        txt += "Run " + (i + 1) + "\r\n";
        txt += "  Time: " + testResults[i].downloadTime + " ms\r\n";
        txt += "  Blob Size: " + testResults[i].downloadedContentLength + " bytes\r\n";
        txt += "  Speed: " + testResults[i].downloadSpeed + " KB/sec\r\n"
    }
    var maxDownloadSpeed = results.maxDownloadSpeed,
        maxDownloadSpeedUnit = "KB/sec";
    if (maxDownloadSpeed > 1024) {
        maxDownloadSpeed = (maxDownloadSpeed / 1024).toFixed(2);
        maxDownloadSpeedUnit = "MB/sec"
    }
    txt += "Max Download speed: " + maxDownloadSpeed + " " + maxDownloadSpeedUnit + "\r\n";
    appendToResultConsole(txt);
    return maxDownloadSpeed + " " + maxDownloadSpeedUnit
}
function runDownloadTest(whatToDownload, trialsToRun) {
    for (var isAdaptiveRun = Array.isArray(whatToDownload),
        testResults = [],
        downloadedContentLength = 0,
        lastRunSpeed = 0,
        prevAdpSpeed = 0,
        i = 0; i < trialsToRun; i++) {
        var url = "";
        if (isAdaptiveRun)
            for (var ai = 0; ai < whatToDownload.length; ai++) {
                var adptFile = whatToDownload[ai];
                if (lastRunSpeed >= adptFile.speed) {
                    url = adptFile.url;
                    if (prevAdpSpeed < adptFile.speed) {
                        i = 0;
                        prevAdpSpeed = adptFile.speed
                    }
                }
            }
        else
            url = whatToDownload;
        var results = xhrLoad(url);
        testResults.push({ downloadTime: results.downloadTime, downloadedContentLength: results.downloadedContentLength, downloadSpeed: Math.floor(results.downloadedContentLength * (1e3 / results.downloadTime) / 1024) });
        lastRunSpeed = results.downloadedContentLength * (1e3 / results.downloadTime) / 1024 / 1024
    }
    var maxDownloadSpeed = 0;
    for (var i in testResults)
        if (testResults[i].downloadTime > 0)
            maxDownloadSpeed = Math.max(maxDownloadSpeed, testResults[i].downloadSpeed);
    return { testResults: testResults, maxDownloadSpeed: maxDownloadSpeed }
}

function xhrLoad(url) {
    var xmlhttp = new XMLHttpRequest,
        startTime = getTime(),
        res = 0,
        downloadedContentLength = 0;
    xmlhttp.onreadystatechange = function () {
        if (xmlhttp.readyState == 4 && xmlhttp.status == 200) {
            var endTime = getTime();
            res = endTime - startTime;
            var headers = xmlhttp.getAllResponseHeaders(),
                clString = "Content-Length: ",
                clIdx = headers.indexOf(clString);
            if (clIdx >= 0) {
                var clEndIdx = headers.indexOf("\n", clIdx);
                if (clEndIdx > 0)
                    downloadedContentLength = headers.substr(clIdx + clString.length, clEndIdx - clIdx - clString.length).replace("\r", "")
            }
        }
    };
    url += "?_rnd=" + Math.floor(Math.random() * 1e8);
    xmlhttp.open("GET", url, false);
    try {
        xmlhttp.send()
    }
    catch (e) {
    }
    return { downloadTime: res, downloadedContentLength: downloadedContentLength }
}