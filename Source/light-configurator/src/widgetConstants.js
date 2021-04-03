export const deviceList = [
  { id: 'B3500', name: 'Captain Marvel', touchScreen: false, settings: true },
  { id: 'B2187', name: 'D2 Air', touchScreen: false, settings: true },
  { id: 'B2819', name: 'D2 Charlie', touchScreen: false, settings: true },
  { id: 'B3197', name: 'D2 Delta', touchScreen: false, settings: true },
  { id: 'B3198', name: 'D2 Delta PX', touchScreen: false, settings: true },
  { id: 'B3196', name: 'D2 Delta S', touchScreen: false, settings: true },
  { id: 'B3499', name: 'Darth Vader', touchScreen: false, settings: true },
  { id: 'B2859', name: 'Descent Mk1', touchScreen: false, settings: true },
  { id: 'B3258', name: 'Descent Mk2 / Descent Mk2i', touchScreen: false, settings: true },
  { id: 'B1836', name: 'Edge 1000 / Explore', touchScreen: true, settings: false },
  { id: 'B2713', name: 'Edge 1030', touchScreen: true, settings: false },
  { id: 'B3095', name: 'Edge 1030 / Bontrager', touchScreen: true, settings: false },
  { id: 'B3570', name: 'Edge 1030 Plus', touchScreen: true, settings: false },
  { id: 'B2067', name: 'Edge 520', touchScreen: false, settings: true },
  { id: 'B3112', name: 'Edge 520 Plus', touchScreen: false, settings: true },
  { id: 'B2530', name: 'Edge 820 / Explore', touchScreen: true, settings: false },
  { id: 'B3122', name: 'Edge 830', touchScreen: true, settings: false },
  { id: 'B3011', name: 'Edge Explore', touchScreen: true, settings: false },
  { id: 'B2697', name: 'fēnix 5 / quatix 5', touchScreen: false, settings: true },
  { id: 'B3110', name: 'fēnix 5 Plus', touchScreen: false, settings: true },
  { id: 'B2544', name: 'fēnix 5S', touchScreen: false, settings: true },
  { id: 'B2900', name: 'fēnix 5S Plus', touchScreen: false, settings: true },
  { id: 'B2604', name: 'fēnix 5X / tactix Charlie', touchScreen: false, settings: true },
  { id: 'B3111', name: 'fēnix 5X Plus', touchScreen: false, settings: true },
  { id: 'B3289', name: 'fēnix 6 / 6 Solar / 6 Dual Power"', touchScreen: false, settings: true },
  { id: 'B3290', name: 'fēnix 6 Pro / 6 Sapphire / 6 Pro Solar / 6 Pro Dual Power / quatix 6', touchScreen: false, settings: true },
  { id: 'B3287', name: 'fēnix 6S / 6S Solar / 6S Dual Power', touchScreen: false, settings: true },
  { id: 'B3288', name: 'fēnix 6S Pro / 6S Sapphire / 6S Pro Solar / 6S Pro Dual Power', touchScreen: false, settings: true },
  { id: 'B3291', name: 'fēnix 6X Pro / 6X Sapphire / 6X Pro Solar / tactix Delta Sapphire / Delta Solar / Delta Solar - Ballistics Edition / quatix 6X / 6X Solar / 6X Dual Power', touchScreen: false, settings: true },
  { id: 'B2432', name: 'fēnix Chronos', touchScreen: false, settings: true },
  { id: 'B3501', name: 'First Avenger', touchScreen: false, settings: true },
  { id: 'B3076', name: 'Forerunner 245', touchScreen: false, settings: true },
  { id: 'B3077', name: 'Forerunner 245 Music', touchScreen: false, settings: true },
  { id: 'B2886', name: 'Forerunner 645', touchScreen: false, settings: true },
  { id: 'B2158', name: 'Forerunner 735xt', touchScreen: false, settings: true },
  { id: 'B3589', name: 'Forerunner 745', touchScreen: false, settings: true },
  { id: 'B2691', name: 'Forerunner 935', touchScreen: false, settings: true },
  { id: 'B3113', name: 'Forerunner 945', touchScreen: false, settings: true },
  { id: 'B3624', name: 'MARQ Adventurer', touchScreen: false, settings: true },
  { id: 'B3251', name: 'MARQ Athlete', touchScreen: false, settings: true },
  { id: 'B3247', name: 'MARQ Aviator', touchScreen: false, settings: true },
  { id: 'B3248', name: 'MARQ Captain / MARQ Captain: American Magic Edition', touchScreen: false, settings: true },
  { id: 'B3249', name: 'MARQ Commander', touchScreen: false, settings: true },
  { id: 'B3246', name: 'MARQ Driver', touchScreen: false, settings: true },
  { id: 'B3250', name: 'MARQ Expedition', touchScreen: false, settings: true },
  { id: 'B3739', name: 'MARQ Golfer', touchScreen: false, settings: true },
  { id: 'B3498', name: 'Rey', touchScreen: false, settings: true },
  { id: 'B3226', name: 'Venu', touchScreen: false, settings: true },
  { id: 'B3740', name: 'Venu Mercedes-Benz Collection', touchScreen: false, settings: true },
  { id: 'B3600', name: 'Venu Sq', touchScreen: false, settings: true },
  { id: 'B3596', name: 'Venu Sq. Music Edition', touchScreen: false, settings: true },
  { id: 'B2700', name: 'vívoactive 3', touchScreen: false, settings: true },
  { id: 'B3473', name: 'vívoactive 3 Mercedes-Benz Collection', touchScreen: false, settings: true },
  { id: 'B2988', name: 'vívoactive 3 Music', touchScreen: false, settings: true },
  { id: 'B3066', name: 'vívoactive 3 Music LTE', touchScreen: false, settings: true },
  { id: 'B3225', name: 'vívoactive 4', touchScreen: false, settings: true },
  { id: 'B3224', name: 'vívoactive 4S', touchScreen: false, settings: true }
];

let map = {};
deviceList.forEach(item => map[item.id] = item);

export const deviceMap = map;

export const getDevice = (device) => {
  return device && deviceMap[device];
};