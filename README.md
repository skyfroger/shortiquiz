[![English](https://img.shields.io/badge/lang-en-blue.svg)](README.md)
[![Русский](https://img.shields.io/badge/lang-ru-red.svg)](README.ru.md)

# Shortiquiz

**Shortiquiz** is an extension for [Quarto](https://quarto.org/) that allows you to add interactive quiz questions to your website pages: multiple-choice questions, text input fields, Parsons problems, flashcards, and much more.

## Installation

Add the extension to your Quarto project:

```bash
quarto add skyfroger/shortiquiz
```

After installation, shortcodes will be available immediately, while filters will require connecting `shortiquiz` to the entire project or to a specific page.

## Localization

To localize the extension's UI elements, specify the `lang` attribute in YAML. English is used by default. Russian is also available:

```yaml
lang: ru
```

## Shortcodes

Shortcodes allow you to embed interactive elements directly into paragraph text.

### `qselect` - dropdown list

Adds a dropdown list with answer options. The **first** specified option is considered correct; options are shuffled before being displayed.

**Syntax:**

```markdown
{{< qselect "option1|option2|option3" show="text" mono=true >}}
```

**Parameters:**

| Parameter | Description |
|-----------|-------------|
| *(first argument)* | Answer options separated by `\|`. The first one is correct. |
| `show` | Text that will be displayed after the correct answer. Optional. |
| `mono` | If `true`, the answer is displayed in a monospaced font. |

> **Answer color:** if the correct answer is given on the first attempt, the text is highlighted in **green**; otherwise, it is **blue**.

**Example:**

```markdown
In Python, the function for converting to an integer is {{< qselect "int()|float()|str()" show="int()" mono=true >}}.
```

### `qinput` - text input field

Adds a text input field for entering an answer. Validation occurs when `Enter` is pressed or when the field loses focus.

**Syntax:**

```markdown
{{< qinput answer1|answer2|... hints="hint" show="text" tol=number size=3 mono=true >}}
```

**Parameters:**

| Parameter | Description |
|-----------|-------------|
| *(first argument)* | Correct answer options separated by `\|`. The first one is used for display if `show` is not set. |
| `tol` | Tolerance for numeric answers. A value in the range `n - tol <= answer <= n + tol` is considered correct. |
| `show` | Text to display in place of the input field after a correct answer. |
| `hints` | Hint text that appears after three incorrect attempts. |
| `mono` | Monospaced font for displaying the correct answer. |
| `size` | Width of the input field (the `size` attribute of the `<input>` tag). Default is `2`. |

**Example 1 - text answer:**

```markdown
Consider a PWM signal with a 50% duty cycle. If the reference voltage is 5 V, the average output voltage will be {{< qinput 2.5|2,5 hints="50% of the voltage value" show="two and a half" size=3 >}} Volts.
```

**Example 2 - numeric answer with tolerance:**

```markdown
Enter a number from 8 to 12: {{< qinput 10 tol=2 >}}.
```

## Filters (block questions)

To use block questions, you need to connect the `shortiquiz` filter (to the entire project or to a specific page).

### Multiple-choice question (`qmulti`)

The question is placed inside a block with the `.qmulti` class. All text before the list is the question text, list items are answer options. The **first item is considered correct.** Options are shuffled when displayed.

**Minimal markup:**

```markdown
:::{.qmulti}

How can you determine the type of a variable?

- Use the `type` function.
- Print the variable's value to the screen and determine its type from the result.
- Use it in an expression whose value is known.
- Look at the variable's description.

:::
```

**Hints and feedback:**

- A blockquote `>` **before** the list is a hint for the question (available via the question mark button after an incorrect answer).
- A blockquote `>` **inside a list item** is feedback for a specific answer option.

**Example with hints and feedback:**

````markdown
:::{.qmulti}

What value will be printed:

```python
print(int(53.785))
```

> What is the easiest way to get a real number from an integer?

- 53

  > The number 53.785 is converted to an integer by the `int` function. The fractional part of the original number is discarded.

- A runtime error will occur.

  > There are no syntax errors in this expression.

- 54

  > The `int` function does not round real numbers.

- 53.785

  > The `int` function converts a number to an integer.

:::
````

### Open-ended question (`qinput`)

A block with the `.qinput` class is used for an open-ended question. The first list item is the correct answer.

**Example:**

````markdown
:::{.qinput}

What will be the result of executing the code:

```python
print(42)
```

> Pay attention to what is written in the parentheses.

- 42

- 24

  > The digits are swapped.

:::
````

### Question with multiple correct answers (`qcheck`)

A block with the `.qcheck` class contains a checklist (`- [ ]` / `- [x]`). Correct options are marked with an `x`.

**Minimal markup:**

```markdown
:::{.qcheck}

Select the options with valid Python variable names.

- [x] `sum`
- [ ] `1st_name`
- [ ] `class`
- [x] `_last_name`
- [x] `Student`

:::
```

**Example with feedback:**

```markdown
:::{.qcheck}

Which of the following is a logical expression?

- [x] `True`

  > `True` and `False` are boolean literals. They can be considered logical expressions.

- [x] `3 == 4`

  > The result of a comparison using `==` is either `True` or `False`.

- [ ] `3 + 4`

  > The value of this expression is a number.

- [x] `3 + 4 == 7`

  > The expression 3+4 equals 7. `7 == 7` is a logical expression.

- [ ] `"False"`

  > The value is in double quotes, so it is a string.

:::
```

### Parsons problems (`qparson`)

An exercise in which you need to arrange lines of code in the correct order.

**Attributes:**

| Attribute | Description |
|-----------|-------------|
| `spaces` | Number of spaces in indentation. Default is `4`. |
| `sep` | Arbitrary separator for combining adjacent lines into a single instruction block. |

**Basic markup example:**

````markdown
:::{.qparson spaces=4}

Elements that are not code blocks are considered the task condition.

These can be images, diagrams, tables.

```python
n = int(input('Enter a number'))
while n > 0:
    print(n)
    n = n - 1
```

:::
````

**Combining lines into blocks:**

If the order of several instructions does not matter, they can be combined using the `sep` separator:

````markdown
:::{.qparson sep=##}

```python
n = int(input("n>"))
sum = 0##
while n > 0:##
    if n % 2 == 0:##
        print(n)
        n = n - 1##
```

:::
````

**Adding distractors:**

Incorrect options (distractors) are placed in the **second** code block inside `.qparson`:

````markdown
:::{.qparson spaces=4 sep=##}

```python
n = int(input())
sum = 0##
while n > 0:##
    if n % 2 == 0:##
        print(n)
        n = n - 1##
```

```py
n = int(input())
sum = 1##
```

:::
````

### Image area selection (`qspot`)

The user is asked to drag numbered markers to the correct image areas.

**The `pos`** attribute specifies the coordinates of the area in the format `x y width height`.

> **Note:** For the demo to work correctly, replace `example.assets/img.png` with the actual path to the image in your project.

```markdown
:::{.qgroup}

:::{.qspot}

![](images/img.png)

Find the following elements in the image:

[photoresistor]{pos="57 24 12 12"}

[red LED]{pos="43 61 13 31"}

[microcontroller]{pos="1 41 58 42"}

> Hint to the question.

:::
```

## Additional features

### Grouping questions (`qgroup`)

Several consecutive questions `qmulti`, `qcheck`, `qinput`, `qparson`, and `qspot` can be grouped together:

```markdown
:::{.qgroup}

:::{.qmulti}
...
:::

:::{.qcheck}
...
:::

:::
```

### Stage unlocking (`qgate` + `qnext`)

Step-by-step instructions where each next stage opens only after a button is clicked.

**Markup:**

```markdown
::::{.qgate name=s1}

... content of the first stage ...

::::

::::{.qgate name=s2}

The next stage opens with a button:

{{< qnext gate=s2 >}}

::::

::::{.qgate name=s2}

This is the final stage of the instructions.

::::
```

> **Important:** the first stage (`s1`) does not require a button and is displayed immediately. The `qnext` button with `gate=s2` is placed inside the previous stage (`s1`) and opens the next one.

### Solution hints (`qsolution`)

The `.qsolution` block contains sequential hints for solving a problem. Each hint is an item in an ordered or unordered list.

- Hints open **sequentially** (one at a time).
- If there is a code block inside the `.qsolution` block, it is considered the **solution to the problem**.
- The solution is only available after all hints have been opened.
- The lines of the solution code are initially hidden and open one at a time; after the tenth line, the entire code can be opened.

**Example:**

````markdown
:::{.qsolution}

1. Use the cascading form of the conditional statement.
2. Note that winter months are numbered 1, 2, and 12.
3. It is sufficient to write logical expressions for three seasons. If none of the three conditions are met, the `else` branch for the remaining last season will execute. This will shorten the code.

```python
month = int(input("Enter the month number (from 1 to 12): "))

if month == 1 or month == 2 or month == 12:
    print("Winter")
elif month >=3 and month <=5:
    print("Spring")
elif month >= 6 and month <= 8:
    print("Summer")
else:
    print("Autumn")
```

:::
````

### Flashcards (`qflashcards`)

A set of cards with questions and answers. The student reads the question, recalls the answer, and then checks themselves. If they cannot recall the answer, the card is added to the end of the deck.

**Markup:**

```markdown
:::{.qflashcards}

- Function for printing values to the screen.

  > `print()`

- Function for reading values from the keyboard.

  > `input()`

- What type of value does the `input()` function return?

  > String (`str`)

- Function for converting values to integers.

  > `int()`

:::
```

> The blockquote `>` inside a list item contains the **answer**. All other elements are part of the question text.

### Question card (`qflip`)

An interactive card with two sides: a question and an answer. Clicking on the card flips it.

**Markup:**

````markdown
:::{.qflip}

Which function can be used to read a value from an analog pin on Arduino?

---

```c++
analogRead(pin);
```

:::
````

> The question and answer are separated by a horizontal line `---` inside the `.qflip` block.

## Markup tips

1. **The correct answer is always first.** In `qmulti`, `qinput` (block), and `qselect`, the first specified option is considered correct. In `qcheck`, correctness is set via `[x]`.
2. **Shuffling.** In `qmulti` and `qselect`, answer options are automatically shuffled before being displayed.
3. **Hints and feedback.** Use blockquotes `>` to add explanations. The placement of the quote (before the list or inside an item) determines its purpose.
4. **Code inside questions.** Quarto supports syntax highlighting inside question blocks - use fenced code blocks (```` ``` ````).
5. **Block nesting.** For `qgroup` and `qgate`, use 4 colons (`::::`) for the outer block to avoid conflicts with inner blocks of 3 colons (`:::`).

## Acknowledgments

The following third-party libraries and modules were used in the development of this extension:

- [Alpine.js](https://alpinejs.dev) for reactive user interface. MIT License.
- [PlainDraggable](https://anseki.github.io/plain-draggable/) for drag-and-drop implementation. MIT License.

The functionality and appearance of this extension were inspired by the following projects:

- [The naquiz extension for Quarto](https://github.com/nareal/naquiz) — the idea of using Alpine.js for reactive UI.
- [mathigon.org](https://mathigon.org/courses) — open-ended and closed-ended text-based questions embedded within the text. I also borrowed the idea of unlocking explanation steps as questions are answered.
- [js-parsons](https://js-parsons.github.io) — the interface and hint system for the Parsons task.
- [quizdown-js](https://github.com/bonartm/quizdown-js) — the idea of grouping a set of questions into a single block.
- [futurecoder.io](https://futurecoder.io) — step-by-step display of code lines when using hints.

Thank you to the developers of these projects.