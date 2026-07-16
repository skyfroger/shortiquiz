local EXTENSION_NAME = "shortiquiz"

local utils = require("./utils")
local l10n  = require("./localize")


return {
  ['qselect'] = function(args, kwargs, meta)
    -- TODO добавить выбор стиля: обычный текст или моноширный.
    utils.writeEnvironments()
    local optionsStr = utils.escapeHtmlDataAttribute(pandoc.utils.stringify(args[1]))

    local showText = utils.escapeHtmlDataAttribute(pandoc.utils.stringify(kwargs["show"]))
    local mono = pandoc.utils.stringify(kwargs["mono"])
    local g = utils.escapeHtmlDataAttribute(pandoc.utils.stringify(kwargs["gate"]))

    local delimiter = "|"
    local options = {}
    for match in string.gmatch(optionsStr, "([^" .. delimiter .. "]+)") do
      table.insert(options, match)
    end

    local correctAnswer = options[1]
    -- какой ответ показывать: из первого параметра или ключа show
    if showText == '' then
      showText = correctAnswer
    end
    -- quarto.log.output(correctAnswer)
    local html = [[
    <span x-data="qselect(']]..correctAnswer..[[', ']]..g..[[')"
    data-gate=']] .. g .. [['>
    <span class="qinput__container" x-show="questionVisibility" x-transition>
      <select class="qselect__select"  x-model="answer">
        <option disabled>???</option>]]

    -- перемешиваем ответы, чтобы правильный ответ не всегда был первым в списке
    utils.ShuffleInPlace(options)

    for _, option in ipairs(options) do
      html = html .. '<option>' .. option .. '</option>'
    end

    -- если выбран моноширный стиль ответа, оборачиваем его в тег <code>
    local answerFormated = showText
    if mono == "true" then
      answerFormated = [[<code>]] .. showText .. [[</code>]]
    end

    html = html .. [[
      </select>
      <span class="qinput__warning" x-show="wrong" x-transition x-cloak>
        <span :class="{ 'shake-head': isShakeHead }">x</span>
      </span>
      </span>
      <span :class="attempt === 1 ? 'q__answer_first_try' : 'q__answer'" x-show="answerVisibility"  x-transition.delay.200ms>]] ..
        answerFormated .. [[</span></span>]]

    return pandoc.RawBlock('html', html)
  end,
  ['qinput'] = function(args, kwargs, meta)
    utils.writeEnvironments()
    local correctAnswer = utils.escapeHtmlDataAttribute(args[1])
    local showText = utils.escapeHtmlDataAttribute(pandoc.utils.stringify(kwargs["show"]))
    local hintsText = pandoc.utils.stringify(kwargs["hints"])
    local size = pandoc.utils.stringify(kwargs["size"])
    local mono = pandoc.utils.stringify(kwargs["mono"])
    local tol = pandoc.utils.stringify(kwargs["tol"])
    local g = utils.escapeHtmlDataAttribute(pandoc.utils.stringify(kwargs["gate"]))


    -- размер поля для ввода по умолчанию
    if size == '' then
      size = '2'
    end

    local tolHtml = nil
    if tol ~= nil and tol ~= "" then
      tolHtml = tol
    else
      tolHtml = "null"
    end

    local html = [[
    <span x-data="qinput(']]..correctAnswer..[[', ]]..tolHtml..[[ , ']]..g..[[')"
    data-gate=']] .. g .. [['>
    <span class="qinput__container" x-show="questionVisibility" x-transition>
      <input type="text" size="]] .. size .. [["   x-model.lazy="answer" placeholder="???" x-on:change="attempt++"/>
      <span class="qinput__warning" x-show="wrong" x-cloak x-transition> <span :class="{ 'shake-head': isShakeHead }">x</span> </span>]]

    if hintsText ~= '' then
      local tipId = utils.RandomStringID(8)
      html = html ..
          [[<span x-show="hints" x-transition x-cloak id="]] .. tipId ..
          [[" class="qinput__tooltip" x-clock>
            <span class="pulse">?</span>
          </span>

          <script>
          tippy('#]] .. tipId .. [[', {
              content: "]] .. hintsText .. [[",
              theme: "qhint",
              maxWidth: 250,
              hideOnClick: false,
          });
          </script>
          ]]
    end


    html = html .. [[</span>]]
    -- какой ответ показывать: из первого параметра или ключа show
    if showText == '' then
      if mono == "true" then
        html = html ..
            [[<span :class="attempt === 1 ? 'q__answer_first_try' : 'q__answer'" x-show="answerVisibility" x-transition.delay.200ms x-cloak>
            <code x-text="correctAnswer[0]"></code>
          </span>]]
      else
        html = html ..
            [[<span :class="attempt === 1 ? 'q__answer_first_try' : 'q__answer'" x-show="answerVisibility" x-text="correctAnswer[0]" x-cloak x-transition.delay.200ms></span>]]
      end
    else
      if mono == "true" then
        html = html ..
            [[<span :class="attempt === 1 ? 'q__answer_first_try' : 'q__answer'" x-show="answerVisibility" x-cloak x-transition.delay.200ms>
            <code>]] .. showText .. [[</code></span>]]
      else
        html = html ..
            [[<span :class="attempt === 1 ? 'q__answer_first_try' : 'q__answer'" x-show="answerVisibility" x-cloak  x-transition.delay.200ms>]] ..
            showText .. [[</span>]]
      end
    end

    html = html .. [[</span>]]

    return pandoc.RawBlock('html', html)
  end,
  ['qnext'] = function(args, kwargs, meta)
    local lang = pandoc.utils.stringify(quarto.metadata.get("lang"))
    l10n.load(lang)

    utils.writeEnvironments()
    
    local text = l10n("next")
    if args[1] ~= nil then
      text = utils.escapeHtmlDataAttribute(pandoc.utils.stringify(args[1]))
    end
    local g = utils.escapeHtmlDataAttribute(pandoc.utils.stringify(kwargs["gate"]))

    local html = [[
    <div class="qnext__container">
    <button
      x-data="qnext(']]..g..[[')"
      x-bind="options"
      data-gate=']] .. g .. [['
    >
    ]]..text..[[
    </button>
    </div>]]
    return pandoc.RawBlock('html', html)
  end
}

