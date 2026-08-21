/// National emergency lines, one tap from the Workshops tab.
///
/// Numbers below are Egypt's published short codes. Anything not centrally
/// published (private towing, desert-road recovery) is deliberately *not*
/// hard-coded — the user adds their own under Workshops so the number is one
/// they actually trust.
enum EmergencyContact {
  police(number: '122', l10nKey: 'emPolice', colorValue: 0xFF3B82F6),
  ambulance(number: '123', l10nKey: 'emAmbulance', colorValue: 0xFFF87171),
  fire(number: '180', l10nKey: 'emFire', colorValue: 0xFFFB923C),
  trafficPolice(number: '128', l10nKey: 'emTraffic', colorValue: 0xFF22D3EE),
  touristPolice(number: '126', l10nKey: 'emTourist', colorValue: 0xFFA78BFA),
  gasEmergency(number: '129', l10nKey: 'emGas', colorValue: 0xFFF59E0B),
  electricity(number: '121', l10nKey: 'emElectricity', colorValue: 0xFFFACC15);

  const EmergencyContact({
    required this.number,
    required this.l10nKey,
    required this.colorValue,
  });

  final String number;
  final String l10nKey;
  final int colorValue;

  /// The four a driver reaches for at the roadside, shown as large tiles.
  static const List<EmergencyContact> primary = [
    police,
    ambulance,
    fire,
    trafficPolice,
  ];
}

/// Roadside safety guidance, rendered as an expandable card. Keys resolve
/// through the normal string tables so the advice is translated, not pasted.
class SafetyTips {
  const SafetyTips._();

  static const List<String> keys = [
    'tipHazardLights',
    'tipPullOverRight',
    'tipTriangle',
    'tipExitFromRight',
    'tipStayBehindBarrier',
    'tipShareLocation',
    'tipKeepKit',
  ];
}
