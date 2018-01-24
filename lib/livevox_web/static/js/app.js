import {Socket} from "phoenix"
import { render, h, Component } from 'preact'

class AgentStatusTable extends Component {
  componentDidMount () {
    const socket = new Socket("/")
    socket.connect()

    this.channel = socket.channel('agent-status')

    this.channel.join()
      .receive('ok', resp =>
        console.log('joined successfully')
      )
      .receive('error', resp =>
        console.log('unable to join', resp)
      )

    this.channel.on('breakdown', statuses => {
      console.log(statuses)
    })
  }

  render(props, state) {
    return <div> I'm rendered </div>
  }
}

console.log('hi')
console.log(document.querySelector('#agent-status'))
render(<AgentStatusTable />, document.querySelector('#agent-status'))
