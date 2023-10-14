#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

getPlayersDataJson() {
  url := 'https://oczki.pl/s2-players/data/api/player-count.php'
  request := ComObject('WinHttp.WinHttpRequest.5.1')
  request.open('GET', url, false)
  request.setRequestHeader('Accept', 'application/json')
  request.send()
  request.waitForResponse()
  return request.ResponseText
}

getPubPlayerCount(json) {
  RegExMatch(json, '"publicServers": (\d+)', &match)
  return match[1]
}

getQueuePlayerCount(json) {
  RegExMatch(json, '"rankedQueues": (\d+)', &match)
  return match[1]
}

getPlayerCounts() {
  json := getPlayersDataJson()
  return [getPubPlayerCount(json), getQueuePlayerCount(json)]
}

main() {
  counts := getPlayerCounts()
  playersInPubs := counts[1]
  playersInQueues := counts[2]
}

main()
