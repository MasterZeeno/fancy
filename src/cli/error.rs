use crate::ansi;

#[derive(Debug)]
pub enum FancyError {
    UnknownColorMode(String),
    ColorParseError(String),
    ColorInvalidUTF8,
    CouldNotReadFromStdin,
    ColorArgRequired,
    CouldNotParseNumber(String),
    StdoutClosed,
    GradientNumberMustBeLargerThanOne,
    GradientColorCountMustBeLargerThanOne,
    DistinctColorCountMustBeLargerThanOne,
    DistinctColorFixedColorsCannotBeMoreThanCount,
    ColorPickerExecutionError(String),
    NoColorPickerFound,
    IoError(std::io::Error),
}

impl FancyError {
    pub fn message(&self) -> String {
        match self {
            FancyError::UnknownColorMode(mode) => {
                format!("Unknown FANCY_COLOR_MODE value ({})", mode)
            }
            FancyError::ColorParseError(color) => format!("Could not parse color '{}'", color),
            FancyError::ColorInvalidUTF8 => "Color input contains invalid UTF8".into(),
            FancyError::CouldNotReadFromStdin => "Could not read color from standard input".into(),
            FancyError::ColorArgRequired => {
                "A color argument needs to be provided on the command line or via a pipe. \
                 Call this command again with '-h' or '--help' to get more information."
                    .into()
            }
            FancyError::CouldNotParseNumber(number) => {
                format!("Could not parse number '{}'", number)
            }
            FancyError::StdoutClosed => "Output pipe has been closed".into(),
            FancyError::GradientNumberMustBeLargerThanOne => {
                "The specified color count must be larger than one".into()
            }
            FancyError::GradientColorCountMustBeLargerThanOne => {
                "The number of color arguments must be larger than one".into()
            }
            FancyError::DistinctColorCountMustBeLargerThanOne => {
                "The number of colors must be larger than one".into()
            }
            FancyError::DistinctColorFixedColorsCannotBeMoreThanCount => {
                "The number of fixed colors must be smaller than the total number of colors".into()
            }
            FancyError::ColorPickerExecutionError(name) => {
                format!("Error while running color picker '{}'", name)
            }
            FancyError::NoColorPickerFound => {
                "Could not find any external color picker tool. See 'fancy pick --help' for more information.".into()
            }
            FancyError::IoError(err) => format!("I/O error: {}", err),
        }
    }
}

impl From<std::io::Error> for FancyError {
    fn from(err: std::io::Error) -> FancyError {
        match err.kind() {
            std::io::ErrorKind::BrokenPipe => FancyError::StdoutClosed,
            _ => FancyError::IoError(err),
        }
    }
}

impl From<ansi::UnknownColorModeError> for FancyError {
    fn from(err: ansi::UnknownColorModeError) -> FancyError {
        FancyError::UnknownColorMode(err.0)
    }
}

pub type Result<T> = std::result::Result<T, FancyError>;
