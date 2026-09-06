package com.maeumjaro.app.content

object SafetyCopy {
    const val disclaimer =
        "이 앱은 의료기기나 의약품이 아니며 진단, 치료, 완치 또는 예방을 목적으로 하지 않습니다. " +
            "실제 의약품이나 의료인의 진료를 대체하지 않으며, 화면 속 표현과 강도는 자기조절을 위한 앱 안의 표현입니다."
}

object ContentPolicy {
    private val forbiddenBrands = Regex("(?i)(마운자로|mounjaro)")
    private val forbiddenClaims = listOf(
        Regex("(?i)\\b\\d+(?:\\.\\d+)?\\s*mg\\b"),
        Regex("(치료|완치|예방|효능|효과).{0,8}(보장|됩니다|있습니다)"),
        Regex("(체중|살).{0,6}(감량|감소|빠짐|빼기)"),
        Regex("(복용|투여|용량|도즈|dose)"),
        Regex("(식욕|충동).{0,6}(억제|제거|차단)"),
        Regex("(약물|의약품).{0,6}(효능|효과|권장|대체)"),
    )

    fun violations(text: String): List<String> {
        if (text == SafetyCopy.disclaimer) return emptyList()
        return buildList {
            forbiddenBrands.find(text)?.value?.let(::add)
            forbiddenClaims.mapNotNullTo(this) { pattern ->
                pattern.find(text)?.value
            }
        }
    }
}
