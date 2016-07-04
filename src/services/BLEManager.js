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

class BLEManager{

  init(){
    BLEPeripheral.createService("7e58")
      .then(() => {
        console.log('service created');
        BLEPeripheral.addCharacteristic("7e58", "b71f", 0, 0)
          .then(() => {
            console.log('characteristic created');
            BLEPeripheral.publishService("7e58")
              .then(() => {
                console.log('service published');
                BLEPeripheral.startAdvertising("7e58", "testbleplugin")
                  .then(() => {
                    console.log('started ads');
                  });
              });
          });
      });


    NativeAppEventEmitter.addListener(
      'BleManagerDiscoverPeripheral',
      (args) => {
        // The id: args.id
        // The name: args.name
        console.log('found peripheral with '+args.id + '/'+ args.name);
      }
    );

  }

}

export default new BLEManager();
