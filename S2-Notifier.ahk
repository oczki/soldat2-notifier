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
    this.checkboxQueue := 'checkboxQueueEnabled'
    this.checkboxMatch := 'checkboxMatchEnabled'
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
  __New(config) {
    this.config := config
    this.countdownTimer := 0 ; TODO: read from setting
    this.countdownTimerMax := 10 ; TODO: read from setting
  }

  update(count) {
    if (this.countdownTimer > 0) {
      this.countdownTimer--
    }
    if (this.countdownTimer <= 0 and not this.__isSoldat2WindowActive()) {
      this.__tickAndResetCountdown(count)
    }
  }

  forceUpdate(count) {
    this.__tickAndResetCountdown(count)
  }

  __tickAndResetCountdown(count) {
    this.countdownTimer := this.countdownTimerMax
    this.__tickForMatches(count.inMatches)
    this.__tickForQueues(count.inQueues)
    this.__tickForPubs(count.inPubs)
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
    hasEnoughPlayers := countInPubs >= this.config.minPlayersInPubs
    shouldNotify := this.config.notifyOfPubs
    return hasEnoughPlayers and shouldNotify
  }

  __shouldNotifyForQueues(countInQueues) {
    hasEnoughPlayers := countInQueues >= this.config.minPlayersInQueues
    shouldNotify := this.config.notifyOfQueues
    return hasEnoughPlayers and shouldNotify
  }

  __shouldNotifyForMatches(countInMatches) {
    hasEnoughPlayers := countInMatches >= this.config.minPlayersInMatches
    shouldNotify := this.config.notifyOfMatches
    return hasEnoughPlayers and shouldNotify
  }

  __isSoldat2WindowActive() {
    return WinActive("ahk_exe soldat2.exe")
  }
}

class GuiWindow {
  __New(config) {
    this.config := config
    this.myGui := this.__create()
    this.show()
  }

  update(count) {
    this.myGui[GuiName().counterPub].Value := count.inPubs
    this.myGui[GuiName().counterQueue].Value := count.inQueues
    this.myGui[GuiName().counterMatch].Value := count.inMatches
  }

  forceUpdate() {
    updater.update()
  }

  show() {
    this.myGui.Show('w600 h400')
  }

  __exit() {
    ExitApp()
  }

  __checkboxPubChanged(*) {
    checked := this.myGui[GuiName().checkboxPub].Value
    this.config.notifyOfPubs := checked
  }

  __checkboxQueueChanged(*) {
    checked := this.myGui[GuiName().checkboxQueue].Value
    this.config.notifyOfQueues := checked
  }

  __checkboxMatchChanged(*) {
    checked := this.myGui[GuiName().checkboxMatch].Value
    this.config.notifyOfMatches := checked
  }

  __create() {
    myGui := Gui(, 'S2 Notifier')
    myGui.OnEvent('Close', this.__exit)

    myGui.Add('Text', 'v' . GuiName().counterPub . ' w150', '0')
    myGui.Add('Text', 'v' . GuiName().counterQueue . ' w150', '0')
    myGui.Add('Text', 'v' . GuiName().counterMatch . ' w150', '0')
    checkboxPub := myGui.Add('Checkbox',
      'v' . GuiName().checkboxPub . ' Checked' . this.config.notifyOfPubs,
      'Notify about public servers')
    checkboxPub.OnEvent('Click', this.__checkboxPubChanged.Bind(this))
    checkboxQueue := myGui.Add('Checkbox',
      'v' . GuiName().checkboxQueue . ' Checked' . this.config.notifyOfQueues,
      'Notify about ranked queues')
    checkboxQueue.OnEvent('Click', this.__checkboxQueueChanged.Bind(this))
    checkboxMatch := myGui.Add('Checkbox',
      'v' . GuiName().checkboxMatch . ' Checked' . this.config.notifyOfMatches,
      'Notify about ranked matches')
    checkboxMatch.OnEvent('Click', this.__checkboxMatchChanged.Bind(this))

    ; dnd hours
    ; mute when s2 window is active
    ; refresh now
    ; input spinner player thresholds
    ; preview sound
    ; countdown to next check
    ; countdown to notif unmute

    return myGui
  }
}

class ConfigFile { ; TODO: have a proxy class so that these values aren't read from disk every minute
  __New() {
    this.__fileDirectory := 'config'
    this.__fileName := this.__fileDirectory . '/config.ini'

    this.__sectionGeneral := 'General'
    this.__sectionPub := 'PublicServers'
    this.__sectionQueue := 'RankedQueues'
    this.__sectionMatch := 'RankedMatches'

    this.__keyMinutesBetweenChecks := 'MinutesBetweenChecks'
    this.__keyMinutesBetweenNotifications := 'MinutesBetweenNotifications'
    this.__keyFeatureEnabled := 'EnableNotifications'
    this.__keyMinimumPlayers := 'MinimumPlayersToNotify'

    if (not this.__configDirectoryExists()) {
      this.__createConfigDirectory()
    }
    if (not this.__configFileExists()) {
      this.__createConfigFile()
    }
  }

  minutesBetweenChecks {
    get {
      readValue := IniRead(this.__fileName,
        this.__sectionGeneral, this.__keyMinutesBetweenChecks, 1)
      return this.__clamp(1, readValue, 60)
    }
    set {
      setValue := this.__clamp(1, value, 60)
      IniWrite(value, this.__fileName,
        this.__sectionGeneral, this.__keyMinutesBetweenChecks)
    }
  }

  minutesBetweenNotifications {
    get {
      readValue := IniRead(this.__fileName,
        this.__sectionGeneral, this.__keyMinutesBetweenNotifications, 1)
      return this.__clamp(1, readValue, 60)
    }
    set {
      setValue := this.__clamp(1, value, 60)
      IniWrite(value, this.__fileName,
        this.__sectionGeneral, this.__keyMinutesBetweenNotifications)
    }
  }

  notifyOfPubs {
    get => IniRead(this.__fileName,
      this.__sectionPub, this.__keyFeatureEnabled, 0)
    set => IniWrite(value, this.__fileName,
      this.__sectionPub, this.__keyFeatureEnabled)
  }

  notifyOfQueues {
    get => IniRead(this.__fileName,
      this.__sectionQueue, this.__keyFeatureEnabled, 0)
    set => IniWrite(value, this.__fileName,
      this.__sectionQueue, this.__keyFeatureEnabled)
  }

  notifyOfMatches {
    get => IniRead(this.__fileName,
      this.__sectionMatch, this.__keyFeatureEnabled, 0)
    set => IniWrite(value, this.__fileName,
      this.__sectionMatch, this.__keyFeatureEnabled)
  }

  minPlayersInPubs {
    get {
      readValue := IniRead(this.__fileName,
        this.__sectionPub, this.__keyMinimumPlayers, 1)
      return this.__clamp(1, readValue, 10)
    }
    set {
      setValue := this.__clamp(1, value, 10)
      IniWrite(value, this.__fileName,
        this.__sectionPub, this.__keyMinimumPlayers)
    }
  }

  minPlayersInQueues {
    get {
      readValue := IniRead(this.__fileName,
        this.__sectionQueue, this.__keyMinimumPlayers, 1)
      return this.__clamp(1, readValue, 10)
    }
    set {
      setValue := this.__clamp(1, value, 10)
      IniWrite(value, this.__fileName,
        this.__sectionQueue, this.__keyMinimumPlayers)
    }
  }

  minPlayersInMatches {
    get {
      readValue := IniRead(this.__fileName,
        this.__sectionMatch, this.__keyMinimumPlayers, 1)
      return this.__clamp(1, readValue, 10)
    }
    set {
      setValue := this.__clamp(1, value, 10)
      IniWrite(value, this.__fileName,
        this.__sectionMatch, this.__keyMinimumPlayers)
    }
  }

  __clamp(valueMin, valueActual, valueMax) {
    if (valueActual < valueMin) {
      return valueMin
    }
    if (valueActual > valueMax) {
      return valueMax
    }
    return valueActual
  }

  __configDirectoryExists() {
    return DirExist(this.__fileDirectory)
  }

  __configFileExists() {
    return FileExist(this.__fileName)
  }

  __createConfigDirectory() {
    DirCreate(this.__fileDirectory)
  }

  __createConfigFile() {
    FileAppend('', this.__fileName)

    this.minutesBetweenNotifications := 10

    this.notifyOfPubs := false
    this.notifyOfQueues := false
    this.notifyOfMatches := false

    this.minPlayersInPubs := 1
    this.minPlayersInQueues := 1
    this.minPlayersInMatches := 1
  }
}

periodicCheck(count, myGui, notifier) {
  count.update()
  myGui.update(count)
  notifier.update(count)

  selfCall := periodicCheck.Bind(count, myGui, notifier)
  SetTimer(selfCall, -60000) ; Run self every minute
}

class PeriodicUpdater {
  __New(config, count, myGui, notifier) {
    this.config := config
    this.count := count
    this.myGui := myGui
    this.notifier := notifier
  }

  update() {
    this.__update()
  }

  __update() {
    this.count.update()
    this.myGui.update(this.count)
    this.notifier.update(this.count)
    this.__startTimer()
  }

  __getTimerPeriodMilliseconds() {
    minutes := this.config.minutesBetweenChecks
    return minutes * 60000
  }

  __startTimer() {
    callback := this.__update.Bind(this)
    SetTimer(callback, -this.__getTimerPeriodMilliseconds())
  }

  __deleteTimer() {
    callback := this.__update.Bind(this)
    SetTimer(callback, 0)
  }
}

main() {
  config := ConfigFile()
  count := CountData()
  myGui := GuiWindow(config)
  notifier := ActivityNotifier(config)
  global updater := PeriodicUpdater(config, count, myGui, notifier)
  updater.update()
}

updater := 0
main()
