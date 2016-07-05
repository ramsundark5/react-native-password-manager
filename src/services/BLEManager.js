import { NativeModules } from 'react-native';
import { NativeAppEventEmitter } from 'react-native';
const BLEPeripheral = NativeModules.BLEPeripheralPlugin;

const properties = {
  READ: 0x02,
  WRITE: 0x08,
  WRITE_NO_RESPONSE: 0x04,
  NOTIFY: 0x10,
  INDICATE: 0x20
};

const permissions= {
  READABLE: 0x01,
  WRITEABLE: 0x02,
  READ_ENCRYPTION_REQUIRED: 0x04,
  WRITE_ENCRYPTION_REQUIRED: 0x08
};

const SERVICE_UUID = "7e58";
const CHARACTERISTIC_UUID = "b71f";

class BLEManager{

  async init(){
    let characteristicProperties = properties.WRITE | properties.READ | properties.NOTIFY;
    let characteristicPermissions = permissions.WRITEABLE | permissions.READABLE;

    await BLEPeripheral.createService(SERVICE_UUID);
    console.log('service created');
    await BLEPeripheral.addCharacteristic(SERVICE_UUID, CHARACTERISTIC_UUID, characteristicProperties, characteristicPermissions);
    console.log('characteristic added');
    await BLEPeripheral.publishService(SERVICE_UUID);
    console.log('service published');
    await BLEPeripheral.startAdvertising(SERVICE_UUID, "testbleplugin2346");
    console.log('started advertising');

    NativeAppEventEmitter.addListener(
      'BleManagerDiscoverPeripheral',
      (args) => {
        // The id: args.id
        // The name: args.name
        console.log('found peripheral with '+args.id + '/'+ args.name);
      }
    );

  }

  async setCharacteristicValue(value){
    await BLEPeripheral.setCharacteristicValue(SERVICE_UUID, CHARACTERISTIC_UUID, value);
    console.log('characteristics value updated');
  }

}

export default new BLEManager();
