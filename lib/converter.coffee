#!/usr/bin/env coffee
#-*- coding: utf-8 -*-

# Filename: converter.coffee
# Created by 请叫我喵 Alynx.
# alynx.zhou@gmail.com, http://alynx.xyz/

fs = require("fs")
path = require("path")

NOT_COMMENT = 0
SINGLE_COMMENT = 1
MULTI_COMMENT = 2

class Converter
  constructor: (@oldEditor, @newEditor) ->
    @validArr = [
      ' ', '\r', '\n', '\t', '|', '(', ')', '{', '}', '[', ']', \
      '<', '>', '0', '1', '2', '3', '4', '5', '6', '7', '#1', \
      '#2', '#3', '#4', '#5', '#6', '#7'
    ]
    @keySeq = [
      '(1)', '(#1)', '(2)', '(#2)', '(3)', '(4)', '(#4)', '(5)', '(#5)', \
      '(6)', '(#6)', '(7)', '1', '#1', '2', '#2', '3', '4', '#4', '5', '#5', \
      '6', '#6', '7', '[1]', '[#1]', '[2]', '[#2]', '[3]', '[4]', '[#4]', \
      '[5]', '[#5]', '[6]', '[#6]', '[7]', '{1}', '{#1}', '{2}', '{#2}', \
      '{3}', '{4}', '{#4}', '{5}', '{#5}', '{6}', '{#6}', '{7}'
    ]
    @digits = ['1', '2', '3', '4', '5', '6', '7']
    @blankArray = ['\n', '\r', '\t', ' ']
    @digitsNotes = JSON.parse(
      fs.readFileSync(path.join(__dirname, "digits-notes.json"))
    )
    @line = ''
    @lineNum = 0
    @bracketObject =
      '(': ')'
      '[': ']'
      '{': '}'
      '': ''  # Keep this line!
    @bracketStatus = ''
    @commentStatus = NOT_COMMENT
    @chordStatus = false
    @chordArray = []
    @noteArray = []
    @rebuildLine = ''
    @finalJSON = []

  tokenSplit: () =>
    i = 0
    while i < @line.length
      switch @commentStatus
        when SINGLE_COMMENT
          @chordArray[@chordArray.length - 1] += @line.charAt(i)
          if @line.charAt(i) is '\n' or i is @line.length - 1
            @commentStatus = NOT_COMMENT
            if not @chordStatus
              @noteArray.push(@chordArray)
              @chordArray = []
          i++
          continue
        when MULTI_COMMENT
          @chordArray[@chordArray.length - 1] += @line.charAt(i)
          if @line.charAt(i) is '*' and @line.charAt(i + 1) is ';'
            @chordArray[@chordArray.length - 1] += @line.charAt(++i)
            @commentStatus = NOT_COMMENT
            if not @chordStatus
              @noteArray.push(@chordArray)
              @chordArray = []
          i++
          continue
      if @line.charAt(i) in @digits
        @chordArray.push(@bracketStatus + @line.charAt(i) + \
        @bracketObject[@bracketStatus])
      else if @line.charAt(i) is '#' and @line.charAt(i + 1) in @digits
        @chordArray.push(@bracketStatus + @line.charAt(i) + \
        @line.charAt(++i) + @bracketObject[@bracketStatus])
      else if @line.charAt(i) is ';' and @line.charAt(i + 1) is ';'
        @chordArray.push(@line.charAt(i) + @line.charAt(++i))
        @commentStatus = SINGLE_COMMENT
      else if @line.charAt(i) is ';' and @line.charAt(i + 1) is '*'
        @chordArray.push(@line.charAt(i) + @line.charAt(++i))
        @commentStatus = MULTI_COMMENT
      else if @line.charAt(i) in @blankArray
        @chordArray.push(@line.charAt(i))
      else if @line.charAt(i) is @bracketObject[@bracketStatus]
        @bracketStatus = ''
      else if @line.charAt(i) of @bracketObject
        @bracketStatus = @line.charAt(i)
      else if @line.charAt(i) is '<'
        @chordStatus = true
      else if @line.charAt(i) is '>'
        @chordStatus = false
      else
        throw new Error("Error: Invalid character `#{@line.charAt(i)}` \
        at Line #{@lineNum + 1}, Column #{i + 1}.")
      if @chordArray.length > 0 and not @chordStatus and \
      @commentStatus is NOT_COMMENT
        @noteArray.push(@chordArray)
        @chordArray = []
      i++

  fixKey: () =>
    i = 0
    while i < @noteArray.length
      switch @noteArray[i]
        when '(#3)' then @noteArray[i] = '(4)'
        when '(#7)' then @noteArray[i] = '1'
        when '#3' then @noteArray[i] = '4'
        when '#7' then @noteArray[i] = '[1]'
        when '[#3]' then @noteArray[i] = '[4]'
        when '[#7]' then @noteArray[i] = '{1}'
        when '{#3}' then @noteArray[i] = '{4}'
      i++

  moveKey: (moveStep) =>
    i = 0
    while i < @noteArray.length
      if @keySeq.indexOf(@noteArray[i]) isnt -1
        if @keySeq.indexOf(@noteArray[i]) + moveStep \
        in [0...@keySeq.length]
          @noteArray[i] = @keySeq[@keySeq.indexOf(@noteArray[i]) + \
          moveStep]
        else
          throw new Error("Error: Cannot move #{@noteArray[i]} \
          with #{moveStep} steps.")
      i++

  checkBlank: (chordArray) =>
    count = 0
    for note in chordArray
      if note in @blankArray
        count++
    return count

  buildJSON: () =>
    for chord in @noteArray
      chordArray = []
      for digit in chord
        if digit in @keySeq
          note = {"timbre": "", "pitch": "", "loudness": 1}
          try
            note["pitch"] = @digitsNotes[digit]
          catch e
            note["pitch"] = ""
          note["loudness"] = 1 / chord.length
          chordArray.push(note)
      if chordArray.length
        @finalJSON.push(chordArray)

  convert: () =>
    lineCount = @oldEditor.getLineCount()
    while @lineNum < lineCount
      try
        @line = @oldEditor.lineTextForBufferRow(@lineNum)
        @tokenSplit()
        @fixKey()
        if commander.move? and commander.move isnt 0
          @moveKey(commander.move)
        if @commentStatus isnt MULTI_COMMENT and not @chordStatus
          @buildJSON()
          @noteArray = []
        @lineNum++
      catch error
        console.error(error)
        if commander.move? and commander.move isnt 0
          @moveKey(commander.move)
        if @commentStatus isnt MULTI_COMMENT and not @chordStatus
          @noteArray = []
        @lineNum++
    @newEditor.insertText(JSON.stringify(@finalJSON, null, "  "))

module.exports = Converter
