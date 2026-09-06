package com.maeumjaro.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.lifecycleScope
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import com.maeumjaro.app.design.MaeumjaroTheme
import com.maeumjaro.app.feature.onboarding.AndroidWidgetPinRequester
import com.maeumjaro.app.feature.onboarding.AppStateOnboardingPersistence
import com.maeumjaro.app.feature.onboarding.OnboardingSettings
import com.maeumjaro.app.core.EntrySource
import com.maeumjaro.app.navigation.LaunchRequest
import com.maeumjaro.app.navigation.LaunchRouter
import com.maeumjaro.app.navigation.MaeumjaroNavHost
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import com.maeumjaro.app.data.settings.AppState
import com.maeumjaro.app.feature.analytics.effectiveEntitlement

class MainActivity : ComponentActivity() {
    private var launchRequest by mutableStateOf<LaunchRequest>(LaunchRequest.AppIcon)
    private var launchRequestNonce by mutableIntStateOf(0)
    private val container by lazy { AppContainer.get(applicationContext) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        launchRequest = intent.toLaunchRequest()
        val persistence = AppStateOnboardingPersistence(container.appStateStore)
        val pinRequester = AndroidWidgetPinRequester(applicationContext)

        setContent {
            val appState by produceState<AppState?>(initialValue = null, container.appStateStore) {
                container.appStateStore.state.collect { value = it }
            }
            val billingState by container.billingRepository.state.collectAsState()
            MaeumjaroTheme(
                themeId = appState?.themeId ?: "default",
                entitlement = billingState.effectiveEntitlement(),
            ) {
                val settings by produceState<OnboardingSettings?>(initialValue = null, persistence) {
                    persistence.settings.collect { value = it }
                }
                val loaded = settings
                if (loaded == null) {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text(stringResource(R.string.loading))
                    }
                } else {
                    val debugReturning = BuildConfig.DEBUG &&
                        intent.getBooleanExtra(EXTRA_SEED_RETURNING, false)
                    val plan = LaunchRouter.resolve(
                        request = launchRequest,
                        onboardingCompleted = loaded.completed || debugReturning,
                    )
                    key(launchRequest, debugReturning, launchRequestNonce) {
                        MaeumjaroNavHost(
                            plan = plan,
                            settings = loaded,
                            persistence = persistence,
                            pinRequester = pinRequester,
                            container = container,
                            launchSource = if (launchRequest is LaunchRequest.VerifiedWidget) EntrySource.WIDGET else EntrySource.APP,
                        )
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        launchRequest = intent.toLaunchRequest()
        launchRequestNonce += 1
    }

    override fun onStart() {
        super.onStart()
        lifecycleScope.launch {
            container.reconcileForeground()
            container.billingRepository.onForeground()
        }
    }

    private fun Intent.toLaunchRequest(): LaunchRequest = LaunchRequest.parse(
        rawSource = getStringExtra(EXTRA_SOURCE),
        verifiedWidget = (BuildConfig.DEBUG && getBooleanExtra(EXTRA_DEBUG_VERIFIED_WIDGET, false)) ||
            (getStringExtra(EXTRA_SOURCE) == com.maeumjaro.app.widget.WidgetLaunchIntentFactory.SOURCE &&
                com.maeumjaro.app.widget.WidgetLaunchAuthenticator.consume(
                    getStringExtra(com.maeumjaro.app.widget.WidgetLaunchIntentFactory.EXTRA_AUTH_TOKEN),
                )),
    )

    companion object {
        const val EXTRA_SEED_RETURNING = "com.maeumjaro.app.debug.SEED_RETURNING"
        const val EXTRA_SOURCE = "com.maeumjaro.app.SOURCE"
        const val EXTRA_DEBUG_VERIFIED_WIDGET = "com.maeumjaro.app.debug.VERIFIED_WIDGET"
    }
}
