import { Socket } from "phoenix";
import { render, h, Component } from "preact";
import AgentStatusTable from './agent-status'
import ThrottleAdjuster from './throttle'

const agent_status_el = () => document.querySelector("#agent-status");
const throttle_el = () => document.querySelector("#throttle");

if (agent_status_el()) {
  render(<AgentStatusTable />, agent_status_el());
} else {
  render(<ThrottleAdjuster />, throttle_el());
}
