import timer from './timer'
import {startTimer, resumeTimer, endTimer, tickTimer} from '../actions'

const dummyAction = {type:'DUMMY', payload:{}}

describe('timer reducer', () => {
  it('default state is "00:00"', () => {
    expect(
      timer(undefined, dummyAction)
    ).to.eql( '00:00' )
  })

  it('starts timer', () => {
    expect(
      timer(undefined, startTimer(25,'pomodoro'))
    ).to.eql( '25:00' )
  })

  it.skip('resumes timer', () => {
    const startTimerAction = startTimer(25,'pomodoro')

    expect(
      timer('00:00', resumeTimer(startTimerAction.payload))
    ).to.eql( '25:00' )
  })

  it('stops timer', () => {
    expect(
      timer('12:34', endTimer())
    ).to.eql( '00:00' )
  })

  it('ticks timer', () => {
    expect(
      timer('25:00', tickTimer(25*60-1))
    ).to.eql( '24:59' )
  })
})