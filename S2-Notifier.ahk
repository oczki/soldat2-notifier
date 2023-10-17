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

class GuiName {
  __New() {
    this.counterPub := 'counterPub'
    this.counterQueue := 'counterQueue'
    this.counterMatch := 'counterMatch'
  }
}

class SoundName {
  __New() {
    this.names := [
      'beeps',
      'bells',
      'movie',
      'retro',
      'success'
    ]
  }

  get(index) {
    return 'sfx/' . this.names[index] . '.wav'
  }
}

class GuiWindow {
  __New() {
    this.countdownTimer := 0
    this.countdownTimerMax := 10
    this.gui := this.__create()
    this.show()
  }

  update(count) {
    this.gui[GuiName().counterPub].Value := count.inPubs
    this.gui[GuiName().counterQueue].Value := count.inQueues
    this.gui[GuiName().counterMatch].Value := count.inMatches
    if (this.countdownTimer > 0)
      this.countdownTimer--
    if (count.inQueues > 0 and this.countdownTimer <= 0 and not WinActive("ahk_exe soldat2.exe")) {
      SoundPlay(SoundName().get(4))
      this.countdownTimer := this.countdownTimerMax
    }
    if (count.inPubs > 0 and this.countdownTimer <= 0 and not WinActive("ahk_exe soldat2.exe")) {
      SoundPlay(SoundName().get(1))
      this.countdownTimer := this.countdownTimerMax
    }
  }

  show() {
    this.gui.Show('w600 h400')
  }

  __exit() {
    ExitApp()
  }

  __create() {
    myGui := Gui(, 'S2 Notifier')
    myGui.OnEvent('Close', this.__exit)

    myGui.Add('Text', 'v' . GuiName().counterPub . ' w150', '0')
    myGui.Add('Text', 'v' . GuiName().counterQueue . ' w150', '0')
    myGui.Add('Text', 'v' . GuiName().counterMatch . ' w150', '0')

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
