#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

class CountData {
  __New() {
    this.inPubs := 0
    this.inQueues := 0
    this.inMatches := 0
  }

  update() {
    json := this.__getJson()
    this.inPubs := this.__parseCountInPublicServers(json)
    this.inQueues := this.__parseCountInRankedQueues(json)
    this.inMatches := this.__parseCountInRankedMatches(json)
  }

  __getJson() {
    url := 'https://oczki.pl/s2-players/data/api/player-count.php'
    request := ComObject('WinHttp.WinHttpRequest.5.1')
    request.open('GET', url, false)
    request.setRequestHeader('Accept', 'application/json')
    request.send()
    request.waitForResponse()
    return request.ResponseText
  }

  __parseCountInPublicServers(json) {
    RegExMatch(json, '"publicServers": (\d+)', &match)
    return match[1]
  }

  __parseCountInRankedQueues(json) {
    RegExMatch(json, '"rankedQueues": (\d+)', &match)
    return match[1]
  }

  __parseCountInRankedMatches(json) {
    RegExMatch(json, '"rankedMatches": (\d+)', &match)
    return match[1]
  }
}

class GuiWindow {
  __New() {
    this.gui := this.__create()
    this.show()
  }

  update(count) {
    MsgBox(count.inPubs . ' ' . count.inQueues . ' ' . count.inMatches)
  }

  show() {
    this.gui.Show('W600 H400')
  }

  __exit() {
    ExitApp()
  }

  __create() {
    myGui := Gui(, 'S2 Notifier')
    myGui.OnEvent('Close', this.__exit)

    return myGui
  }
}

notifyIfNeeded(count) {
}

periodicCheck(count, myGui) {
  count.update()
  myGui.update(count)
  notifyIfNeeded(count)

  selfCall := periodicCheck.Bind(count, myGui)
  SetTimer(selfCall, -60000) ; Run self every minute
}

main() {
  count := CountData()
  myGui := GuiWindow()
  periodicCheck(count, myGui)
}

main()
