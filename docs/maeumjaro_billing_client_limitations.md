# 마음자로 Android Billing 경계

`PlayBillingEntitlementRepository`는 비소모성 일회성 상품 `pro_lifetime`을 위한 순수 경계다. 실제 Billing 9.1.0 `BillingClient` 콜백은 `BillingGateway` 어댑터에서 연결한다. 연결부는 `queryProductDetailsAsync`, `queryPurchasesAsync(QueryProductTypeParams)`와 `acknowledgePurchase`를 매핑하고, 구매 토큰을 로그나 영구 저장소에 남기지 않는다.

상태는 `Unknown`, `Free`, `Pending`, `Pro`, `Error`로 제한한다. `PURCHASED`인 정확한 상품만 Pro가 되며, `PENDING`·오류·다른 상품·계정 범위 변경은 잠금 상태로 처리한다. 소유 목록에 다른 상품이 섞여도 fail-closed 한다. 빈 상품 ID·계정 범위·토큰도 fail-closed 한다. 성공한 무소유 조회는 캐시를 지우고 Free로 내린다. 오프라인/연결 오류에서는 마지막 확인 Pro 캐시를 `Error.cachedPro`로 노출하지만 새 구매의 근거로 사용하지 않는다.

구매 시작은 매번 Billing 연결을 보장한 뒤 상품을 조회한다. 조회에 포함된 모든 eligible `PURCHASED` 항목을 acknowledgement하고, 같은 토큰은 동시 callback에서도 single-flight로 한 번만 처리한다. 이 구현은 의도적으로 서버 검증을 하지 않는 client-only 경계다. 따라서 환불·취소·변조 반영이 늦을 수 있고 다음 성공한 Play 조회에서 교정된다. 출시 전 OWNER/EXTERNAL GATE에서 최종 상품 ID, 라이선스 테스터, 내부 트랙 구매·Pending·취소·복원·재설치·승인 확인을 별도로 검증해야 한다.

공식 참고:

- https://developer.android.com/google/play/billing/integrate
- https://developer.android.com/google/play/billing/one-time-products
- https://developer.android.com/google/play/billing/test
