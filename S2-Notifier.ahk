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

    this.checkboxPub := 'checkboxPubEnabled'
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

class ActivityNotifier {
  __New() {
    this.enableForPubs := 0 ; TODO: read from setting
    this.enabledForQueues := 0 ; TODO: read from setting
    this.enableForMatches := 0 ; TODO: read from setting

    this.countdownTimer := 0 ; TODO: read from setting
    this.countdownTimerMax := 10 ; TODO: read from setting
  }

  update(count) {
    if (this.countdownTimer > 0) {
      this.countdownTimer--
    }
    if (this.countdownTimer <= 0 and not this.__isSoldat2WindowActive()) {
      this.countdownTimer := this.countdownTimerMax
      this.__tickForMatches(count.inMatches)
      this.__tickForQueues(count.inQueues)
      this.__tickForPubs(count.inPubs)
    }
  }

  __tickForPubs(countInPubs) {
    if (this.__shouldNotifyForPubs(countInPubs)) {
      SoundPlay(SoundName().get(1), true) ; TODO: extract to allow previewing
    }
  }

  __tickForQueues(countInQueues) {
    if (this.__shouldNotifyForQueues(countInQueues)) {
      SoundPlay(SoundName().get(4), true) ; TODO: extract to allow previewing
    }
  }

  __tickForMatches(countInMatches) {
    if (this.__shouldNotifyForMatches(countInMatches)) {
      SoundPlay(SoundName().get(5), true) ; TODO: extract to allow previewing
    }
  }

  __shouldNotifyForPubs(countInPubs) {
    hasEnoughPlayers := countInPubs >= 1 ; TODO: use setting instead of hardcoded 1
    return hasEnoughPlayers
  }

  __shouldNotifyForQueues(countInQueues) {
    hasEnoughPlayers := countInQueues >= 1 ; TODO: use setting instead of hardcoded 1
    return hasEnoughPlayers
  }

  __shouldNotifyForMatches(countInMatches) {
    hasEnoughPlayers := countInMatches >= 1 ; TODO: use setting instead of hardcoded 1
    return hasEnoughPlayers
  }

  __isSoldat2WindowActive() {
    return WinActive("ahk_exe soldat2.exe")
  }
}

class GuiWindow {
  __New() {
    this.gui := this.__create()
    this.show()
  }

  update(count) {
    this.gui[GuiName().counterPub].Value := count.inPubs
    this.gui[GuiName().counterQueue].Value := count.inQueues
    this.gui[GuiName().counterMatch].Value := count.inMatches
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
    isCheckboxChecked := 0 ; TODO: read from setting
    myGui.Add('Checkbox', 'v' . GuiName().checkboxPub . ' Checked' . isCheckboxChecked, 'Notify of activity on public servers')

    return myGui
  }
}

periodicCheck(count, myGui, notifier) {
  count.update()
  myGui.update(count)
  notifier.update(count)

  selfCall := periodicCheck.Bind(count, myGui, notifier)
  SetTimer(selfCall, -60000) ; Run self every minute
}

main() {
  count := CountData()
  myGui := GuiWindow()
  notifier := ActivityNotifier()
  periodicCheck(count, myGui, notifier)
}

main()
