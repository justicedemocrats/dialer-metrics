import { Socket } from "phoenix";
import { render, h, Component } from "preact";

export default class ThrottleAdjuster extends Component {
  state = {
    throttle: null
  };

  componentDidMount() {
    const socket = new Socket("/socket");
    socket.connect();

    this.channel = socket.channel("live");

    this.channel
      .join()
      .receive("ok", resp => {
        console.log("joined successfully");
        this.channel.push("get-throttle", {
          service: document
            .querySelector("#throttle")
            .getAttribute("data-service")
        });
      })
      .receive("error", resp => {
        console.log("unable to join", resp);
      });

    this.channel.on("throttle", throttle => {
      console.log("got update");
      this.setState(Object.assign(throttle, { changing: false }));
    });

    setInterval(this.update, 5000);
  }

  update = () =>
    this.channel.push("get-throttle", {
      service: document.querySelector("#throttle").getAttribute("data-service")
    });

  onChange = ev => {
    this.setState({ changing: true });
    this.channel.push("set-throttle", {
      service: document.querySelector("#throttle").getAttribute("data-service"),
      value: parseInt(ev.target.value)
    });
  };

  render(props, state) {
    const { throttle, changing } = state;
    return (
      <div>
        <div
          style={{
            padding: 10,
            fontSize: 40,
            border: "1px solid black",
            textAlign: "center"
          }}
        >
          {changing ? <span class="loader loader-info" /> : parseInt(throttle)}
        </div>
        <div style={{ display: "flex", justifyContent: "space-around" }}>
          <div> 0 </div>
          <input
            onChange={this.onChange}
            type="range"
            min="0"
            max="5"
            step="1"
            style={{ maxWidth: "80%" }}
          />
          <div> 5 </div>
        </div>
      </div>
    );
  }
}
