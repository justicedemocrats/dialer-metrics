import { Socket } from "phoenix";
import { render, h, Component } from "preact";

Array.prototype.flatMap = function(lambda) {
  return Array.prototype.concat.apply([], this.map(lambda));
};

const label_map = {
  not_ready: "Not Ready",
  in_call: "In Call",
  ready: "Ready",
  wrap_up: "Wrap Up"
};

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
          service: document
            .querySelector("#agent-status")
            .getAttribute("data-service")
        });
      })
      .receive("error", resp => {
        console.log("unable to join", resp);
      });

    this.channel.on("breakdown", statuses => {
      console.log("got update");
      console.log(statuses);
      this.setState(statuses);
    });

    setInterval(this.update, 5000);
  }

  update = () =>
    this.channel.push("status-for-service", {
      service: document
        .querySelector("#agent-status")
        .getAttribute("data-service")
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
          {Object.keys(label_map).flatMap(key =>
            state[key].map(({ calling_from, caller_email, phone, login }) => (
              <tr>
                <td>{label_map[key]}</td>
                <td>{calling_from}</td>
                <td>{caller_email}</td>
                <td>{phone}</td>
                <td>{login}</td>
              </tr>
            ))
          )}
        </tbody>
      </table>
    );
  }
}
