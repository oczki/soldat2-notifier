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
  static counterPub := 'counterPub'
  static counterQueue := 'counterQueue'
  static counterMatch := 'counterMatch'

  static checkboxPub := 'checkboxPubEnabled'
  static checkboxQueue := 'checkboxQueueEnabled'
  static checkboxMatch := 'checkboxMatchEnabled'
}

class SoundPlayer {
  static playPubSound() {
    this.__play('pub')
  }

  static playQueueSound() {
    this.__play('queue')
  }

  static playMatchSound() {
    this.__play('match')
  }

  static __play(soundName) {
    waitForSoundToFinish := true
    SoundPlay('sfx/' . soundName . '.wav', waitForSoundToFinish)
  }
}

class ActivityNotifier {
  __New(config) {
    this.config := config
    this.countdownTimer := 0
    this.countdownTimerMax := config.minutesBetweenNotifications
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
    this.countdownTimerMax := this.config.minutesBetweenNotifications
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
      SoundPlayer.playPubSound()
    }
  }

  __tickForQueues(countInQueues) {
    if (this.__shouldNotifyForQueues(countInQueues)) {
      SoundPlayer.playQueueSound()
    }
  }

  __tickForMatches(countInMatches) {
    if (this.__shouldNotifyForMatches(countInMatches)) {
      SoundPlayer.playMatchSound()
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
    this.myGui[GuiName.counterPub].Value := count.inPubs
    this.myGui[GuiName.counterQueue].Value := count.inQueues
    this.myGui[GuiName.counterMatch].Value := count.inMatches
  }

  forceUpdate() {
    updater.update()
  }

  show() {
    this.myGui.Show('w600 h400')
  }

  __create() {
    myGui := Gui(, 'S2 Notifier')
    myGui.OnEvent('Close', this.__exit.Bind(this))

    this.__addCounter(myGui, GuiName.counterPub)
    this.__addCounter(myGui, GuiName.counterQueue)
    this.__addCounter(myGui, GuiName.counterMatch)

    this.__addCheckboxPub(myGui)
    this.__addCheckboxQueue(myGui)
    this.__addCheckboxMatch(myGui)

    ; dnd hours
    ; mute when s2 window is active
    ; refresh now
    ; input spinner player thresholds
    ; preview sound
    ; countdown to next check
    ; countdown to notif unmute

    return myGui
  }

  __checkboxPubChanged(*) {
    checked := this.myGui[GuiName.checkboxPub].Value
    this.config.notifyOfPubs := checked
  }

  __checkboxQueueChanged(*) {
    checked := this.myGui[GuiName.checkboxQueue].Value
    this.config.notifyOfQueues := checked
  }

  __checkboxMatchChanged(*) {
    checked := this.myGui[GuiName.checkboxMatch].Value
    this.config.notifyOfMatches := checked
  }

  __addCounter(myGui, controlName) {
    myGui.AddText('v' . controlName . ' w150', '0')
  }

  __addCheckboxPub(myGui) {
    checkbox := myGui.AddCheckbox(
      'v' . GuiName.checkboxPub . ' Checked' . this.config.notifyOfPubs,
      'Notify about public servers')
    checkbox.OnEvent('Click', this.__checkboxPubChanged.Bind(this))
  }

  __addCheckboxQueue(myGui) {
    checkbox := myGui.AddCheckbox(
      'v' . GuiName.checkboxQueue . ' Checked' . this.config.notifyOfQueues,
      'Notify about ranked queues')
    checkbox.OnEvent('Click', this.__checkboxQueueChanged.Bind(this))
  }

  __addCheckboxMatch(myGui) {
    checkbox := myGui.AddCheckbox(
      'v' . GuiName.checkboxMatch . ' Checked' . this.config.notifyOfMatches,
      'Notify about ranked matches')
    checkbox.OnEvent('Click', this.__checkboxMatchChanged.Bind(this))
  }

  __exit(*) {
    this.config.saveToFile()
    ExitApp()
  }
}

class ConfigProxy {
  __New(configFile) {
    this.configFile := configFile
    this.__readFromFile()
  }
  
  saveToFile() {
    this.configFile.minutesBetweenChecks := this.minutesBetweenChecks
    this.configFile.minutesBetweenNotifications := this.minutesBetweenNotifications
    
    this.configFile.notifyOfPubs := this.notifyOfPubs
    this.configFile.notifyOfQueues := this.notifyOfQueues
    this.configFile.notifyOfMatches := this.notifyOfMatches

    this.configFile.minPlayersInPubs := this.minPlayersInPubs
    this.configFile.minPlayersInQueues := this.minPlayersInQueues
    this.configFile.minPlayersInMatches := this.minPlayersInMatches
  }

  minutesBetweenChecks {
    get => this.__clampMinutes(this.__minutesBetweenChecks)
    set => this.__minutesBetweenChecks := this.__clampMinutes(value)
  }

  minutesBetweenNotifications {
    get => this.__clampMinutes(this.__minutesBetweenNotifications)
    set => this.__minutesBetweenNotifications := this.__clampMinutes(value)
  }

  notifyOfPubs {
    get => this.__clampBoolean(this.__notifyOfPubs)
    set => this.__notifyOfPubs := this.__clampBoolean(value)
  }

  notifyOfQueues {
    get => this.__clampBoolean(this.__notifyOfQueues)
    set => this.__notifyOfQueues := this.__clampBoolean(value)
  }

  notifyOfMatches {
    get => this.__clampBoolean(this.__notifyOfMatches)
    set => this.__notifyOfMatches := this.__clampBoolean(value)
  }

  minPlayersInPubs {
    get => this.__clampPlayerCount(this.__minPlayersInPubs)
    set => this.__minPlayersInPubs := this.__clampPlayerCount(value)
  }

  minPlayersInQueues {
    get => this.__clampPlayerCount(this.__minPlayersInQueues)
    set => this.__minPlayersInQueues := this.__clampPlayerCount(value)
  }

  minPlayersInMatches {
    get => this.__clampPlayerCount(this.__minPlayersInMatches)
    set => this.__minPlayersInMatches := this.__clampPlayerCount(value)
  }

  __readFromFile() {
    this.minutesBetweenChecks := this.configFile.minutesBetweenChecks
    this.minutesBetweenNotifications := this.configFile.minutesBetweenNotifications

    this.notifyOfPubs := this.configFile.notifyOfPubs
    this.notifyOfQueues := this.configFile.notifyOfQueues
    this.notifyOfMatches := this.configFile.notifyOfMatches

    this.minPlayersInPubs := this.configFile.minPlayersInPubs
    this.minPlayersInQueues := this.configFile.minPlayersInQueues
    this.minPlayersInMatches := this.configFile.minPlayersInMatches
  }

  __clampBoolean(val) {
    return this.__clamp(0, val, 1)
  }

  __clampMinutes(val) {
    return this.__clamp(1, val, 60)
  }

  __clampPlayerCount(val) {
    return this.__clamp(1, val, 10)
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
}

class ConfigFile {
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
    get => IniRead(this.__fileName,
      this.__sectionGeneral, this.__keyMinutesBetweenChecks, 1)
    set => IniWrite(value, this.__fileName,
      this.__sectionGeneral, this.__keyMinutesBetweenChecks)
  }

  minutesBetweenNotifications {
    get => IniRead(this.__fileName,
      this.__sectionGeneral, this.__keyMinutesBetweenNotifications, 1)
    set => IniWrite(value, this.__fileName,
      this.__sectionGeneral, this.__keyMinutesBetweenNotifications)
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
    get => IniRead(this.__fileName,
      this.__sectionPub, this.__keyMinimumPlayers, 1)
    set => IniWrite(value, this.__fileName,
      this.__sectionPub, this.__keyMinimumPlayers)
  }

  minPlayersInQueues {
    get => IniRead(this.__fileName,
      this.__sectionQueue, this.__keyMinimumPlayers, 1)
    set => IniWrite(value, this.__fileName,
      this.__sectionQueue, this.__keyMinimumPlayers)
  }

  minPlayersInMatches {
    get => IniRead(this.__fileName,
      this.__sectionMatch, this.__keyMinimumPlayers, 1)
    set => IniWrite(value, this.__fileName,
      this.__sectionMatch, this.__keyMinimumPlayers)
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

    this.minutesBetweenChecks := 1
    this.minutesBetweenNotifications := 10

    this.notifyOfPubs := false
    this.notifyOfQueues := false
    this.notifyOfMatches := false

    this.minPlayersInPubs := 1
    this.minPlayersInQueues := 1
    this.minPlayersInMatches := 1
  }
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
    ; Period is negative, so it'll only run once
    SetTimer(callback, -this.__getTimerPeriodMilliseconds())
  }

  __deleteTimer() {
    callback := this.__update.Bind(this)
    SetTimer(callback, 0)
  }
}

main() {
  ; Proxy is used to reduce reads/writes; config file is written on exit
  configFileActual := ConfigFile()
  configFileProxy := ConfigProxy(configFileActual)

  count := CountData()
  myGui := GuiWindow(configFileProxy)
  notifier := ActivityNotifier(configFileProxy)
  global updater := PeriodicUpdater(configFileProxy, count, myGui, notifier)
  updater.update()
}

updater := 0
main()
