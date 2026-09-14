# CAP Kubernetes homelab

This project started with a question: could I understand the CAP theorem better by watching it happen on my own machine?

The example is a small ticket-booking app written in Ruby and Sinatra. There is one seat, A1, and two offices selling it. Alice books at one office. Bob tries the other. As long as the offices can talk, they can share what they know. Things get interesting when that connection breaks.

The lab starts with Docker Compose. First, each office keeps its own bookings, which makes it possible to sell the seat twice. Then one office becomes the authority, and the other has to ask it before confirming a booking. That prevents independent decisions, but leaves the second office unable to book when it cannot reach the first.

Later, both offices make local decisions and exchange records in the background. After a network partition, they eventually agree on the records: Alice and Bob both have a confirmed booking. Replication worked. The seat is still double-booked.

Once that behavior is familiar, the same app moves into k3d. Pods, Deployments, Services, and NetworkPolicy become easier to connect to something concrete: keeping an office running, finding it after a restart, or stopping the offices from talking to each other. Kubernetes doesn't change the booking rules for us.

## Following along

[Start with the setup](notes/00-start-here.md), then follow the [notes in order](notes/README.md). They include the commands, why we run them, and the results to look for. They also cover the problems encountered along the way, including the Docker Desktop forwarding issue.

The early lessons use specific Git commits because the app changes as the experiments progress. Running the latest code for every lesson would skip some of the behavior we're trying to observe. The setup walks through creating a separate worktree for those Docker experiments.

If you're returning to the lab, these are useful places to pick it up:

- [Two independent offices](notes/04-two-offices.md)
- [The first Kubernetes Deployment and Pod replacement](notes/17-k3d-deployment-and-recovery.md)
- [Blocking communication with NetworkPolicy](notes/20-kubernetes-network-partition.md)
- [Conflicting bookings after the connection returns](notes/22-kubernetes-partition-conflict.md)
- [A reusable client command with Ruby and ConfigMaps](notes/23-declarative-client-utility.md)

## Running it locally

The lab was built in Ubuntu on WSL with Docker Desktop, Docker Compose, Git, Bash, and curl. The Kubernetes lessons also use k3d and kubectl. Ruby and its dependencies run in containers; there's no need to install Ruby or a database on your machine. You'll need internet access for the initial downloads.

Read the setup before starting containers. The Docker replay uses ports 14567 and 14568 and its own worktree. The Kubernetes lessons return to the original checkout and explain what needs to be running before each experiment.

Bookings live in memory, so restarting an office can lose its records. There is also no code to decide which customer gets the seat after a double booking. Keep those limits in mind when interpreting the results.

The notes separate recorded results from checks a reader should expect when replaying a lesson. The [validation report](notes/15-validation.md) covers the separately tested Docker sequence; Kubernetes results are recorded in their respective lessons. If something behaves differently, start with the [troubleshooting notes](notes/14-troubleshooting.md).
