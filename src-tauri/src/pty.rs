use anyhow::{Context, Result};
use portable_pty::{native_pty_system, Child, CommandBuilder, MasterPty, PtySize};
use std::io::{BufRead, BufReader, Write};
use std::sync::{Arc, Mutex};

pub struct PtySession {
    pub writer: Arc<Mutex<Box<dyn Write + Send>>>,
    pub _child: Box<dyn Child + Send + Sync>,
}

pub fn spawn_pty(command: &str, cwd: &str) -> Result<(PtySession, Box<dyn std::io::Read + Send>)> {
    let pty_system = native_pty_system();
    let pair = pty_system
        .openpty(PtySize {
            rows: 48,
            cols: 160,
            pixel_width: 0,
            pixel_height: 0,
        })
        .context("failed to open pty")?;

    let mut cmd = CommandBuilder::new(command);
    cmd.cwd(cwd);

    let child = pair.slave.spawn_command(cmd).context("failed to spawn pty command")?;
    let writer = pair.master.take_writer().context("failed to take pty writer")?;
    let reader = pair.master.try_clone_reader().context("failed to clone pty reader")?;

    Ok((
        PtySession {
            writer: Arc::new(Mutex::new(writer)),
            _child: child,
        },
        reader,
    ))
}

pub fn for_each_line(mut reader: Box<dyn std::io::Read + Send>, mut f: impl FnMut(String) + Send + 'static) {
    std::thread::spawn(move || {
        let mut buffered = BufReader::new(&mut reader);
        loop {
            let mut line = String::new();
            match buffered.read_line(&mut line) {
                Ok(0) => break,
                Ok(_) => f(line),
                Err(_) => break,
            }
        }
    });
}
