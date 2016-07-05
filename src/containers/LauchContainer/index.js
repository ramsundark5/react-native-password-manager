/* @flow */

import React, { Component } from 'react'
import { Platform, TextInput } from 'react-native'
import { Actions } from 'react-native-router-flux'
import Container from '@components/Container'
import Title from '@components/Title'
import Button from '@components/Button'
import BLEManager from '../../services/BLEManager'

class LauchContainer extends Component {

  constructor(props, context) {
    super(props, context);
    this.state = {
      text: '',
    };
  }

  componentDidMount(){
    BLEManager.init();
  }

  updateCharacteristicValue(){
    BLEManager.setCharacteristicValue(this.state.text);
    this.setState({text: ''});
  }

  render() {
    return (
      <Container>
        <Title>Hello there 😃 !</Title>
        <TextInput
          style={{height: 40, borderColor: 'gray', borderWidth: 1}}
          onChangeText={(text) => this.setState({text: text})}
          value={this.state.text}
        />
        <Button onPress={() => this.updateCharacteristicValue()}>Send</Button>
      </Container>
    )
  }
}

export default LauchContainer;
