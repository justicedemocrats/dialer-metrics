import { Socket } from "phoenix";
import { render, h, Component } from "preact";

export default class AgentStatusTable extends Component {
  state = {
    not_ready: [],
    in_call: [],
    ready: [],
    wrap_up: []
  };

  componentDidMount() {
    const socket = new Socket("/socket");
    socket.connect();

    this.channel = socket.channel("live");

    this.channel
      .join()
      .receive("ok", resp => {
        console.log("joined successfully");
        this.channel.push("status-for-service", {
          service: document.querySelector('#agent-status').getAttribute("data-service")
        });
      })
      .receive("error", resp => {
        console.log("unable to join", resp);
      });

    this.channel.on("breakdown", statuses => {
      console.log('got update')
      this.setState(statuses);
    });

    setInterval(this.update, 5000)
  }

  update = () =>
    this.channel.push("status-for-service", {
      service: document.querySelector('#agent-status').getAttribute("data-service")
    });

  render(props, state) {
    const { not_ready, in_call, ready, wrap_up } = state;
    return (
      <table
        class="table-striped table-bordered"
        style={{ transform: "scale(1)" }}
      >
        <thead>
          <tr>
            <th>Status</th>
            <th>Calling From</th>
            <th>Email</th>
            <th>Phone</th>
            <th>Livevox Login</th>
          </tr>
        </thead>
        <tbody>
          {not_ready.map(({ calling_from, caller_email, phone, login }) => (
            <tr>
              <td>Not Ready</td>
              <td>{calling_from}</td>
              <td>{caller_email}</td>
              <td>{phone}</td>
              <td>{login}</td>
            </tr>
          ))}
        </tbody>
      </table>
    );
  }
}
