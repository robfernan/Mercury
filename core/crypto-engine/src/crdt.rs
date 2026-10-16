//! Lamport timestamps and Last-Write-Wins (LWW) registers for CRDT reconciliation.

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct LamportClock {
    pub counter: u64,
    pub node_id: String,
}

impl LamportClock {
    pub fn new(node_id: String) -> Self {
        Self { counter: 0, node_id }
    }

    pub fn tick(&mut self) -> u64 {
        self.counter += 1;
        self.counter
    }

    pub fn merge(&mut self, other_counter: u64) {
        self.counter = self.counter.max(other_counter) + 1;
    }
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct LwwRegister {
    pub value: String,
    pub timestamp: u64,
    pub writer_id: String,
}

impl LwwRegister {
    pub fn new(value: String, timestamp: u64, writer_id: String) -> Self {
        Self { value, timestamp, writer_id }
    }

    pub fn merge(&self, other: &Self) -> Self {
        if self.timestamp > other.timestamp {
            self.clone()
        } else if other.timestamp > self.timestamp {
            other.clone()
        } else if self.writer_id >= other.writer_id {
            self.clone()
        } else {
            other.clone()
        }
    }
}
