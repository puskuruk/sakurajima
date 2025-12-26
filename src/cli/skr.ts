#!/usr/bin/env zx
/**
 * 🏴 SAKURAJIMA CLI (skr)
 * The unified entry point for the Sakurajima environment
 *
 * This is THE interface for managing the Sakurajima environment.
 * Users should never need to cd to ~/setup or run npm scripts directly.
 */

import { $, argv, chalk, fs, path } from 'zx';
import {
  bold,
  ok,
  info,
  warn,
  die,
  ensureDir,
  fileExists,
  commandExists,
  SETUP_DIR,
  WORKSPACE_DIR,
  CLIENTS_DIR,
  LOCAL_BIN,
  dirExists,
} from '../lib/common.ts';

const VERSION = '0.2.0';

// Local zx path - NEVER rely on global zx
const ZX_BIN = path.join(SETUP_DIR, 'node_modules', '.bin', 'zx');

// Sakura-themed banner
const SAKURA = chalk.magenta('❀');
const BANNER = `${SAKURA} ${chalk.bold.magentaBright('S')}${SAKURA}${chalk.bold.magentaBright('A')}${SAKURA}${chalk.bold.magentaBright('K')}${SAKURA}${chalk.bold.magentaBright('U')}${SAKURA}${chalk.bold.magentaBright('R')}${SAKURA}${chalk.bold.magentaBright('A')}${SAKURA}${chalk.bold.magentaBright('J')}${SAKURA}${chalk.bold.magentaBright('I')}${SAKURA}${chalk.bold.magentaBright('M')}${SAKURA}${chalk.bold.magentaBright('A')} ${SAKURA}`;

function showHelp(): void {
  console.log(`
${BANNER}
${chalk.dim(`CLI v${VERSION} — My mind is a mountain`)}

${bold('Usage:')} skr <command> [args]

${bold('Setup & Maintenance:')}
  install        Run initial Sakurajima installation
  verify         Run system verification
  update         Update system and tools
  uninstall      Remove Sakurajima environment

${bold('Client Workspaces:')}
  new <name>     Create a new client workspace
  list           List all client workspaces
  focus <name>   Focus a client (time tracking + workspace switch)
  unfocus        Stop current time tracking session
  stats [name]   View time tracking statistics

${chalk.dim('TIP: Use shell function `focus <name>` to also cd to client dir')}

${bold('Configuration:')}
  gen            Regenerate all configs (AeroSpace, Raycast)
  gen-aerospace  Regenerate AeroSpace config only
  gen-raycast    Regenerate Raycast commands only

${bold('Infrastructure:')}
  infra up       Start local infra (Mongo, Postgres, Redis)
  infra down     Stop local infra
  infra backup   Backup databases
  infra status   Show docker container status

${bold('Applications:')}
  apps list      List available Docker and Homebrew apps
  apps install   Install a Docker or Homebrew application
  apps search    Search for applications
  apps info      Show detailed information about an app
  apps running   Show running Docker containers

${chalk.dim('TIP: Use `skr apps install postgres` as shorthand for docker apps')}
${chalk.dim('     Full syntax: `sakurajima-apps install docker postgres`')}

${bold('Misc:')}
  logo           Display the Sakurajima logo
  version        Show version

${bold('Aliases:')}
  i → infra    n → new    v → verify    u → update    s → stats

${bold('Examples:')}
  skr new acme           Create 'acme' client workspace
  skr focus acme         Start working on 'acme' project
  skr unfocus            Stop time tracking
  skr stats acme         Show stats for 'acme' client
  skr infra up           Start Docker infrastructure
  skr apps install postgres      Install PostgreSQL (Docker)
  skr apps install obsidian      Install Obsidian (Homebrew)
`);
}

async function runZxScript(scriptPath: string, args: string[] = []): Promise<void> {
  const fullPath = path.join(SETUP_DIR, 'src', scriptPath);
  await $`${ZX_BIN} ${fullPath} ${args}`;
}

async function cmdInfra(subCmd: string): Promise<void> {
  const infraDir = path.join(SETUP_DIR, 'infra');
  const dataDir = path.join(WORKSPACE_DIR, 'data');

  // Set environment variable for docker-compose
  process.env.SAKURAJIMA_DATA_DIR = dataDir;

  switch (subCmd) {
    case 'up':
    case 'start':
      await ensureDir(dataDir);
      await $`docker compose -f ${infraDir}/docker-compose.yml up -d`;
      ok('Infrastructure started');
      break;
    case 'down':
    case 'stop':
      await $`docker compose -f ${infraDir}/docker-compose.yml down`;
      ok('Infrastructure stopped');
      break;
    case 'backup':
    case 'dump':
      // TODO: Implement backup
      warn('Backup not yet implemented in zx version');
      break;
    case 'status':
    case 'ps':
      await $`docker compose -f ${infraDir}/docker-compose.yml ps`;
      break;
    default:
      die(`Unknown infra command: ${subCmd}. Try: up, down, backup, status`);
  }
}

async function listClients(): Promise<void> {
  if (!(await dirExists(CLIENTS_DIR))) {
    info('No clients configured yet. Run: skr new <client-name>');
    return;
  }

  const entries = await fs.readdir(CLIENTS_DIR, { withFileTypes: true });
  const clients = entries
    .filter((e: { isDirectory: () => boolean; name: string }) =>
      e.isDirectory() && !e.name.startsWith('_') && !e.name.startsWith('.')
    )
    .map((e: { name: string }) => e.name)
    .sort();

  if (clients.length === 0) {
    info('No clients configured yet. Run: skr new <client-name>');
    return;
  }

  console.log(bold('Client Workspaces:'));
  clients.forEach((client: string, i: number) => {
    console.log(`  ${i + 1}. ${client}`);
  });
  console.log();
  info(`Total: ${clients.length} client(s)`);
}

async function main(): Promise<void> {
  const command = argv._[0] as string | undefined;
  const args = argv._.slice(1).map(String);

  if (!command || command === 'help' || command === 'h' || argv.help) {
    showHelp();
    return;
  }

  try {
    switch (command) {
      // Setup & Maintenance
      case 'install':
      case 'setup':
        await runZxScript('install.ts', args);
        break;

      case 'verify':
      case 'v':
        await runZxScript('verify-system.ts', args);
        break;

      case 'update':
      case 'u':
        await runZxScript('update-all.ts', args);
        break;

      case 'uninstall':
        await runZxScript('uninstall.ts', args);
        break;

      // Client Workspace commands
      case 'new':
      case 'n':
        if (!args[0]) {
          die('Client name required. Usage: skr new <client-name>');
        }
        await runZxScript('client/new.ts', args);
        break;

      case 'list':
      case 'ls':
        await listClients();
        break;

      case 'focus':
        if (!args[0]) {
          die('Client name required. Usage: skr focus <client>');
        }
        await runZxScript('time/start.ts', args);
        break;

      case 'unfocus':
      case 'stop':
        await runZxScript('time/unfocus.ts', args);
        break;

      case 'stats':
      case 's':
        await runZxScript('time/stats.ts', args);
        break;

      case 'time-init':
        await runZxScript('time/init.ts', args);
        break;

      case 'time-cleanup':
        await runZxScript('time/cleanup.ts', args);
        break;

      // Config commands
      case 'gen':
        // Regenerate all configs
        info('Regenerating AeroSpace config...');
        await runZxScript('generate-aerospace-config.ts', []);
        info('Regenerating Raycast commands...');
        await $`generate-sakurajima-commands`.quiet().catch(() => {
          warn('Raycast commands generation skipped (script not found)');
        });
        ok('All configs regenerated');
        break;

      case 'gen-aerospace':
        await runZxScript('generate-aerospace-config.ts', args);
        break;

      case 'gen-raycast':
        await $`generate-sakurajima-commands`;
        break;

      // Infrastructure commands
      case 'infra':
      case 'i':
        await cmdInfra(args[0] || 'status');
        break;

      // Application management
      case 'apps':
      case 'app':
        if (!(await commandExists('sakurajima-apps'))) {
          die('sakurajima-apps not found. Run: skr install');
        }

        const appCmd = args[0];
        const appArgs = args.slice(1);

        if (!appCmd) {
          // Show available commands
          await $`sakurajima-apps --help`;
          break;
        }

        // Smart detection: if user types `skr apps install postgres`, assume docker
        if (appCmd === 'install' && appArgs.length === 1) {
          const appName = appArgs[0];

          // Check if it's in docker catalog
          const catalogPath = path.join(SETUP_DIR, 'configs', 'apps-catalog.json');
          if (await fileExists(catalogPath)) {
            const catalog = JSON.parse(await fs.readFile(catalogPath, 'utf-8'));

            const isDockerApp = catalog.docker?.some((app: { slug: string }) => app.slug === appName);
            const isBrewApp = catalog.homebrew?.some((app: { slug: string }) => app.slug === appName);

            if (isDockerApp && !isBrewApp) {
              // It's a Docker app, use docker automatically
              await $`sakurajima-apps install docker ${appName}`;
              break;
            } else if (isBrewApp && !isDockerApp) {
              // It's a Homebrew app, use brew automatically
              await $`sakurajima-apps install brew ${appName}`;
              break;
            } else if (isDockerApp && isBrewApp) {
              // Ambiguous - ask user or default to docker
              warn(`App '${appName}' exists in both Docker and Homebrew catalogs`);
              info('Defaulting to Docker. Use `sakurajima-apps install brew ${appName}` for Homebrew version');
              await $`sakurajima-apps install docker ${appName}`;
              break;
            }
          }
        }

        // Otherwise pass through to sakurajima-apps
        await $`sakurajima-apps ${appCmd} ${appArgs}`;
        break;

      // Development commands
      case 'typecheck':
      case 'tc':
        info('Running TypeScript type check...');
        await $`npm run typecheck --prefix ${SETUP_DIR}`;
        break;

      case 'test':
        info('Running tests...');
        await $`npm test --prefix ${SETUP_DIR}`;
        break;

      // Logo
      case 'logo':
        const logoScript = path.join(LOCAL_BIN, 'sakurajima-logo');
        if (await commandExists('sakurajima-logo')) {
          await $`sakurajima-logo`;
        } else if (await fileExists(logoScript)) {
          await $`${logoScript}`;
        } else {
          // Fallback to the script in repo
          const repoLogo = path.join(SETUP_DIR, 'scripts', 'sakurajima-logo');
          await $`bash ${repoLogo}`;
        }
        break;

      // Version
      case 'version':
      case '--version':
      case '-v':
        console.log(`${BANNER}`);
        console.log(chalk.dim(`v${VERSION}`));
        break;

      default:
        warn(`Unknown command: ${command}`);
        console.log();
        showHelp();
        process.exit(1);
    }
  } catch (err) {
    if (err instanceof Error) {
      die(err.message);
    }
    throw err;
  }
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
