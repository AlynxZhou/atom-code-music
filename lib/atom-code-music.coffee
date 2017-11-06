fs = require("fs")
path = require("path")
{CompositeDisposable} = require("atom")
base64Binary = require(path.join(__dirname, "base64binary"))
timbres =
  "Piano": require(path.join(__dirname, "timbres", "acoustic_grand_piano-ogg"))
  "Marimba": require(path.join(__dirname, "timbres", "marimba-ogg"))
Converter = require(path.join(__dirname, "converter"))
keysNotes = JSON.parse(fs.readFileSync(
  path.join(__dirname, "keys-notes.json")
))
sheetsArray = fs.readdirSync(path.join(__dirname, "sheets"))

class AtomCodeMusic
  constructor: () ->
    @readyTimbres = 0
    @timbresLength = 0
    @i = 0
    @subscriptions = new CompositeDisposable()
    @sheet = []
    @sheets= {}
    @audioSources = {}
    @timbresAudio = {}
    @switch = false
    @workMode = ""
    @timbre = ""
    @customSheets = ""

  activate: () =>
    @context = new AudioContext()
    @gainNode = @context.createGain()
    @gainNode.connect(@context.destination)
    @gainNode.gain.value = 1
    @subscriptions.add(atom.commands.add("atom-workspace", \
    "atom-code-music:toggle": @toggle))
    @subscriptions.add(atom.commands.add("atom-text-editor", \
    "atom-code-music:convert": @convert))
    @changeMode()
    @changeTimbre()
    @changeSheets()
    @subscriptions.add(atom.config.onDidChange("atom-code-music.workMode", \
    @changeMode))
    @subscriptions.add(atom.config.onDidChange("atom-code-music.timbre", \
    @changeTimbre))
    @subscriptions.add(atom.config.onDidChange("atom-code-music.customSheets", \
    @changeSheets))
    @loadSheets()
    @loadTimbre()

  deactivate: () =>
    @subscriptions.dispose()

  loadSheets: () =>
    for sheetName in sheetsArray
      @sheets[sheetName] = JSON.parse(fs.readFileSync(
        path.join(__dirname, "sheets", sheetName)
      ))

  loadTimbre: () =>
    # Use two closure wrappers to save the status.
    # Because decodeAudioData() is an async method.
    for timbre of timbres then do (timbre) =>
      @timbresAudio[timbre] = []
      for pitch of timbres[timbre] then do (pitch) =>
        @context.decodeAudioData(base64Binary.decodeArrayBuffer(
          timbres[timbre][pitch].split("data:audio/ogg;base64,")[1]), \
          (audioBuffer) =>
            @timbresAudio[timbre][pitch] = audioBuffer
            ++@readyTimbres
        )
    for timbre of timbres
      for pitch of timbres[timbre]
        ++@timbresLength


  changeMode: () =>
    @workMode = atom.config.get("atom-code-music.workMode")
    if @workMode is "Music Box Mode" and not @sheet?.length
      @sheet = Object.keys(@sheets)[Math.floor(
        Math.random() * Object.keys(@sheets).length
      )]
    for k in @audioSources
      if @audioSources[k] instanceof Array
        for source in @audioSources[k]
          source.stop(@context.currentTime + 0.3)
      else
        @audioSources[k].stop(@context.currentTime + 0.3)
      @audioSources = null

  changeTimbre: =>
    @timbre = atom.config.get("atom-code-music.timbre")
    if @timbre is "Random"
      @timbre = Object.keys(@timbresAudio)[Math.floor(
        Math.random() * Object.keys(@timbresAudio).length
      )]

  changeSheets: =>
    @customSheets = atom.config.get("atom-code-music.customSheets")
    if @customSheets.length
      @customSheets = @customSheets.replace(/, /g, ',')
      customSheetsArray = @customSheets.split(',')
      for customSheetName in customSheetsArray
        if customSheetName not of @sheets
          try
            @sheets[customSheetName] = JSON.parse(
              fs.readFileSync(path.join(customSheetName))
            )
          catch error
            continue

  noteOn: (event) =>
    if @readyTimbres isnt @timbresLength or \
    event.repeat or @audioSources[event.code]? or \
    event.code not of keysNotes
      return
    # console.log(event.code)
    switch (@workMode)
      when "Music Box Mode"
        if event.code in ["ControlLeft", "ControlRight", "AltLeft", \
        "AltRight", "ShiftLeft", "ShiftRight"]
          return
        if (not @sheets[@sheet]?) or @i >= @sheets[@sheet]?.length
          @sheet = Object.keys(@sheets)[Math.floor(
            Math.random() * Object.keys(@sheets).length
          )]
          @changeTimbre()
          @i = 0
        sources = []
        for note in @sheets[@sheet][@i]
          if note["timbre"] isnt ""
            @timbre = note["timbre"]
          if note["pitch"] of @timbresAudio[@timbre]
            @gainNode.gain.value = note["loudness"]
            source = @context.createBufferSource()
            source.connect(@gainNode)
            source.buffer = @timbresAudio[@timbre][note["pitch"]]
            source.start(0)
            sources.push(source)
        @audioSources[event.code] = sources
        @i++
      when "Real Piano Mode"
        if event.code not of @audioSources
          @gainNode.gain.value = 5
          source = @context.createBufferSource()
          source.connect(@gainNode)
          source.buffer = @timbresAudio[@timbre][keysNotes[event.code]]
          source.start(0)
          @audioSources[event.code] = source

  noteOff: (event) =>
    if @readyTimbres isnt @timbresLength or \
    event.repeat or event.code not of keysNotes or \
    not @audioSources[event.code]?
      return
    switch (@workMode)
      when "Music Box Mode"
        sources = @audioSources[event.code]
        for source in sources
          source.stop(@context.currentTime + 0.3)
        delete @audioSources[event.code]
      when "Real Piano Mode"
        @audioSources[event.code].stop(@context.currentTime + 0.3)
        delete @audioSources[event.code]

  toggle: () =>
    if not @switch then @enable() else @disable()

  enable: () =>
    if not @switch
      atom.views.getView(atom.workspace).addEventListener("keydown", @noteOn)
      atom.views.getView(atom.workspace).addEventListener("keyup", @noteOff)
      @switch = true

  disable: () =>
    if @switch
      atom.views.getView(atom.workspace).removeEventListener("keydown", @noteOn)
      atom.views.getView(atom.workspace).removeEventListener("keyup", @noteOff)
      @switch = false

  convert: () ->
    oldEditor = atom.workspace.getActiveTextEditor()
    (atom.workspace.open()).then(->
      newEditor = atom.workspace.getActiveTextEditor()
      lineConverter = new Converter(oldEditor, newEditor)
      lineConverter.convert()
    )

module.exports = AtomCodeMusic
