fn main() {
    println!("{}", greeting());
}

fn greeting() -> &'static str {
    "Hello from rust-skeleton!"
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn greets() {
        assert_eq!(greeting(), "Hello from rust-skeleton!");
    }
}
