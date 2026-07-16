function registerSQComponents() {
    Alpine.data("qspot", () => ({
        markersList: [],
        targetsList: [],
        answerStatusList: [],
        attempt: 0,
        isShowFeedback: false,
        isAnswerCorrect: false,
        isHintVisible: false,
        init() {
            const container = this.$refs.container;
            const markers = container.querySelectorAll(".marker");
            const markersCount = markers.length;
            markers.forEach((marker, i) => {
                const m = new PlainDraggable(marker, { leftTop: true });
                m.element.style.zIndex = markersCount * 100 - i;
                m.onMoveStart = () => {
                    this.isShowFeedback = false;
                };
                this.markersList.push(m);
            });

            this.targetsList = Array.from(
                container.querySelectorAll(".qspot__area"),
            );

            this.answerStatusList = Array(markers.length).fill(false);
        },
        isCollide(target, marker) {
            const t = target.getBoundingClientRect();
            const m = marker.element.getBoundingClientRect();
            return !(
                t.top > m.bottom ||
                t.right < m.left ||
                t.bottom < m.top ||
                t.left > m.right
            );
        },
        getMarkerClass(index) {
            if (!this.isShowFeedback) return "";
            return this.answerStatusList[index] ? "correct" : "wrong";
        },
        checkAnswer() {
            this.attempt++;
            this.isShowFeedback = true;

            for (let index = 0; index < this.targetsList.length; index++) {
                const target = this.targetsList[index];
                const marker = this.markersList[index];
                const collision = this.isCollide(target, marker);
                this.answerStatusList[index] = collision;
                if (collision) {
                    marker.disabled = true;
                    marker.element.style.opacity = 0;
                    target.classList.add("correct");
                }
            }

            this.isAnswerCorrect = !this.answerStatusList.includes(false);
        },
    }));

    Alpine.data("qselect", (correctAnswer, gate = "") => ({
        answer: "???",
        isCorrect: false,
        attempt: 0,
        correctAnswer: correctAnswer,
        get answerVisibility() {
            return this.isCorrect;
        },
        get questionVisibility() {
            return !this.isCorrect;
        },
        get wrong() {
            return this.answer !== "???" && this.answer !== this.correctAnswer;
        },
        isShakeHead: false,
        init() {
            this.$watch("answer", (value) => {
                this.isCorrect =
                    this.answer === this.correctAnswer ? true : false;
                this.attempt++;
                if (!this.isCorrect) this.shake();
                this.$dispatch("answer-notification", {
                    isCorrect: this.isCorrect,
                    type: "qselect",
                    gate: gate,
                    attempt: this.attempt,
                });
            });
        },
        shake() {
            this.isShakeHead = true;
            setTimeout(() => {
                this.isShakeHead = false;
            }, 600);
        },
    }));

    Alpine.data("qinput", (correctAnswer, tol = 0, gate = "") => ({
        answer: "",
        isCorrect: false,
        correctAnswer: correctAnswer.split("|"),
        attempt: 0,
        tol: tol,
        get answerVisibility() {
            return this.isCorrect;
        },
        get questionVisibility() {
            return !this.isCorrect;
        },
        get wrong() {
            return this.answer !== "" && !this.setIsCorrect(this.answer);
        },
        get hints() {
            return this.wrong && this.attempt >= 3;
        },
        isShakeHead: false,
        init() {
            this.$watch("answer", (value) => {
                this.isCorrect = this.setIsCorrect(this.answer);
                if (!this.isCorrect) this.shake();
                this.$dispatch("answer-notification", {
                    isCorrect: this.isCorrect,
                    type: "qinput",
                    gate: gate,
                    attempt: this.attempt,
                });
            });
        },
        shake() {
            this.isShakeHead = true;
            setTimeout(() => {
                this.isShakeHead = false;
            }, 600);
        },
        setIsCorrect(val) {
            if (this.tol !== null) {
                val = val.replace(",", ".");
                const a = Number(this.correctAnswer[0]);
                if (
                    Number(val) <= a + this.tol &&
                    Number(val) >= a - this.tol
                ) {
                    // ответ попадает в диапазон
                    this.correctAnswer[0] = val; // введённый ответ выведем как правильный
                    return true;
                } else {
                    return false;
                }
            } else {
                // если не задана точность
                return this.correctAnswer.includes(val);
            }
        },
    }));

    Alpine.data("qnext", (gate = "") => ({
        isVisible: true,
        options: {
            ["x-show"]() {
                return this.isVisible;
            },
            ["x-cloak"]() {
                return true;
            },
            ["x-transition"]() {
                return true;
            },
            ["@click"]() {
                this.isVisible = !this.isVisible;
                this.$dispatch("answer-notification", {
                    isCorrect: true,
                    type: "qnext",
                    gate: gate,
                    attempt: 1,
                });
            },
        },
    }));
}

if (window.Alpine) {
    registerSQComponents();
} else {
    document.addEventListener("alpine:init", () => {
        registerSQComponents();
    });
}
