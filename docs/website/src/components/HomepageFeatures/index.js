import clsx from 'clsx';
import Heading from '@theme/Heading';
import styles from './styles.module.css';

const FeatureList = [
  {
    title: 'Fresh Server Per Run',
    Svg: require('@site/static/img/undraw_docusaurus_mountain.svg').default,
    description: (
      <>
        Every workflow run gets a brand-new, ephemeral Aruba Cloud server.
        No shared state between jobs, no idle costs between runs — the server
        is created at job start and deleted at job end.
      </>
    ),
  },
  {
    title: 'Zero Network Setup Required',
    Svg: require('@site/static/img/undraw_docusaurus_tree.svg').default,
    description: (
      <>
        Skip VPC, subnet, and security group pre-creation — the action provisions
        them automatically when you omit those inputs, and cleans them up after.
        Bring your own network when you prefer.
      </>
    ),
  },
  {
    title: 'Fully Configurable',
    Svg: require('@site/static/img/undraw_docusaurus_react.svg').default,
    description: (
      <>
        Choose any supported flavor (1–32 vCPU), OS image, boot disk size,
        and runner labels. Inject pre-boot scripts via{' '}
        <code>pre_runner_script</code> to install tooling before your job starts.
      </>
    ),
  },
];

function Feature({Svg, title, description}) {
  return (
    <div className={clsx('col col--4')}>
      <div className="text--center">
        <Svg className={styles.featureSvg} role="img" />
      </div>
      <div className="text--center padding-horiz--md">
        <Heading as="h3">{title}</Heading>
        <p>{description}</p>
      </div>
    </div>
  );
}

export default function HomepageFeatures() {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className="row">
          {FeatureList.map((props, idx) => (
            <Feature key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}
