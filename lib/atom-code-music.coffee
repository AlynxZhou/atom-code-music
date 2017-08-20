fs = require("fs")
path = require("path")
{CompositeDisposable} = require("atom")
timbres =
  "Piano": require(path.join(__dirname, "timbres", "acoustic_grand_piano-ogg"))
  "Marimba": require(path.join(__dirname, "timbres", "marimba-ogg"))
Converter = require(path.join(__dirname, "converter"))

class AtomCodeMusic
  constructor: () ->
    @i = 0
    @base64Binary = require(path.join(__dirname, "base64binary"))
    @keysNotes = JSON.parse(fs.readFileSync(
      path.join(__dirname, "keys-notes.json")
    ))
    @subscriptions = new CompositeDisposable()
    @sheet = []
    @sheets= {}
    sheetsArray = fs.readdirSync(path.join(__dirname, "sheets"))
    for sheetName in sheetsArray
      @sheets[sheetName] = JSON.parse(fs.readFileSync(
        path.join(__dirname, "sheets", sheetName)
      ))
    # Use two closure wrappers to save the status.
    # Because decodeAudioData() is an async method.
    @sources = []
    @context = new AudioContext()
    @gainNode = @context.createGain()
    @gainNode.connect(@context.destination)
    @gainNode.gain.value = 1
    @timbresAudio = {}
    for timbre of timbres then do (timbre) =>
      @timbresAudio[timbre] = []
      for pitch of timbres[timbre] then do (pitch) =>
        @context.decodeAudioData(@base64Binary.decodeArrayBuffer(
          timbres[timbre][pitch].split("data:audio/ogg;base64,")[1]), \
          (audioBuffer) =>
            @timbresAudio[timbre][pitch] = audioBuffer
        )
    @switch = false
    @workMode = ""
    @timbre = ""
    @customSheets = ""

  activate: =>
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

  deactivate: () =>
    @subscriptions.dispose()

  changeMode: () =>
    @workMode = atom.config.get("atom-code-music.workMode")
    if @workMode is "Music Box Mode" and not @sheet?.length
      @sheet = Object.keys(@sheets)[Math.floor(
        Math.random() * Object.keys(@sheets).length
      )]

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
    # console.log(event.code)
    switch (@workMode)
      when "Music Box Mode"
        if event.code not in ["ControlLeft", "ControlRight", "AltLeft", \
        "AltRight", "ShiftLeft", "ShiftRight"]
          if (not @sheets[@sheet]?) or @i >= @sheets[@sheet]?.length
            @sheet = Object.keys(@sheets)[Math.floor(
              Math.random() * Object.keys(@sheets).length
            )]
            @changeTimbre()
            @i = 0
          for note in @sheets[@sheet][@i]
            if note["timbre"] isnt ""
              @timbre = note["timbre"]
            if note["pitch"] of @timbresAudio[@timbre]
              @gainNode.gain.value = note["loudness"]
              source = @context.createBufferSource()
              source.connect(@gainNode)
              source.buffer = @timbresAudio[@timbre][note["pitch"]]
              source.start(0)
              @sources.push(source)
          @i++
      when "Real Piano Mode"
        if event.code of @keysNotes
          @gainNode.gain.value = 1
          source = @context.createBufferSource()
          source.connect(@gainNode)
          source.buffer = @timbresAudio[@timbre][@keysNotes[event.code]]
          source.start(0)
          @sources.push(source)

  noteOff: (event) =>
    switch (@workMode)
      when "Music Box Mode"
        for source in @sources
          source?.stop(@context.currentTime + 0.5)
      when "Real Piano Mode"
        for source in @sources
          if event.code of @keysNotes
            source?.stop(@context.currentTime + 0.5)

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
