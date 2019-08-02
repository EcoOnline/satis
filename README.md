# Satis configuration and usage

We are using [Satis](https://getcomposer.org/doc/articles/handling-private-packages-with-satis.md) as our Composer repository generator.

Once Satis is installed, we build our repository using this [configuration file](./content/satis.json).

The repository should be built at regular intervals, preferably every five minutes by scheduling a cronjob or something similar.
