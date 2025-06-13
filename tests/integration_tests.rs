use assert_cmd::Command;

fn fancy() -> Command {
    let mut cmd = Command::cargo_bin("fancy").unwrap();
    cmd.env_remove("FANCY_COLOR_MODE");
    cmd
}

#[test]
fn color_reads_colors_from_args() {
    fancy()
        .arg("color")
        .arg("red")
        .assert()
        .success()
        .stdout("hsl(0,100.0%,50.0%)\n");

    fancy()
        .arg("color")
        .arg("red")
        .arg("blue")
        .assert()
        .success()
        .stdout("hsl(0,100.0%,50.0%)\nhsl(240,100.0%,50.0%)\n");

    fancy().arg("color").arg("no color").assert().failure();
}

#[test]
fn color_reads_colors_from_stdin() {
    fancy()
        .arg("color")
        .write_stdin("red\nblue\n")
        .assert()
        .success()
        .stdout("hsl(0,100.0%,50.0%)\nhsl(240,100.0%,50.0%)\n");

    fancy()
        .arg("color")
        .write_stdin("no color")
        .assert()
        .failure();
}

#[test]
fn format_basic() {
    fancy()
        .arg("format")
        .arg("hex")
        .arg("red")
        .assert()
        .success()
        .stdout("#ff0000\n");

    fancy()
        .arg("format")
        .arg("rgb")
        .arg("red")
        .arg("blue")
        .assert()
        .success()
        .stdout("rgb(255, 0, 0)\nrgb(0, 0, 255)\n");
}

#[test]
fn pipe_into_format_command() {
    let first = fancy()
        .arg("color")
        .arg("red")
        .arg("teal")
        .arg("hotpink")
        .assert()
        .success();

    fancy()
        .arg("format")
        .arg("name")
        .write_stdin(String::from_utf8(first.get_output().stdout.clone()).unwrap())
        .assert()
        .success()
        .stdout("red\nteal\nhotpink\n");
}

#[test]
fn sort_by_basic() {
    fancy()
        .arg("sort-by")
        .arg("luminance")
        .arg("gray")
        .arg("white")
        .arg("black")
        .assert()
        .success()
        .stdout("hsl(0,0.0%,0.0%)\nhsl(0,0.0%,50.2%)\nhsl(0,0.0%,100.0%)\n");
}

#[test]
fn set_basic() {
    fancy()
        .arg("set")
        .arg("hsl-hue")
        .arg("120")
        .arg("red")
        .assert()
        .success()
        .stdout("hsl(120,100.0%,50.0%)\n");

    fancy()
        .arg("set")
        .arg("hsl-saturation")
        .arg("0.1")
        .arg("red")
        .assert()
        .success()
        .stdout("hsl(0,10.0%,50.0%)\n");

    fancy()
        .arg("set")
        .arg("hsl-lightness")
        .arg("0.5")
        .arg("white")
        .assert()
        .success()
        .stdout("hsl(0,0.0%,50.0%)\n");
}
