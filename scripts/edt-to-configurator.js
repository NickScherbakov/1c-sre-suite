// ==============================================================================
// CLI-утилита и Agent Skill: Бесшовный мост из 1C:EDT в Конфигуратор
// ==============================================================================
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const os = require('os');

// Декларативное описание скилла для ИИ-агентов (по спецификации Agent Skills)
const SKILL_METADATA = {
  name: "edt_to_configurator",
  description: "Автоматически транслирует текстовые исходные коды проектов 1C:EDT в бинарные форматы Конфигуратора (.cf/.cfe) на Windows и Linux",
  arguments: {
    projectDir: "Путь к корню проекта EDT (где лежит .project и src/)",
    output: "Абсолютный путь для сохранения бинарного .cfe или .cf",
    edtVersion: "Конкретная версия EDT для запуска через ring (например, edt@2025.2.0)"
  }
};

const args = process.argv.slice(2);
const command = args[0];

if (command !== "convert") {
  console.log("Укажите команду 'convert' и аргументы:");
  console.log("node edt-to-configurator.js convert --projectDir <path> --output <file.cfe>");
  process.exit(1);
}

// Простой парсинг аргументов командной строки
const getArg = (flag) => {
  const index = args.indexOf(flag);
  return (index !== -1 && args[index + 1]) ? args[index + 1] : null;
};

const projectDir = getArg("--projectDir");
const output = getArg("--output");
let edtVersion = getArg("--edtVersion");

if (!projectDir || !output) {
  console.error("[-] Ошибка: Отсутствуют обязательные параметры --projectDir и/или --output");
  process.exit(1);
}

const absoluteProjDir = path.resolve(projectDir);
const absoluteOutput = path.resolve(output);

// 1. Извлечение имени расширения/проекта из .project
const projectFilePath = path.join(absoluteProjDir, '.project');
if (!fs.existsSync(projectFilePath)) {
  console.error(`[-] Ошибка: В указанном каталоге отсутствует служебный файл EDT: ${projectFilePath}`);
  process.exit(1);
}

const projectFileContent = fs.readFileSync(projectFilePath, 'utf-8');
const nameMatch = projectFileContent.match(/<name>(.*?)<\/name>/);
const extensionName = nameMatch ? nameMatch[1] : "TemporaryBuildExtension";
console.log(`[*] Обнаружено имя проекта EDT: ${extensionName}`);

// 2. Автоопределение установленной версии EDT в реестре ring
if (!edtVersion) {
  try {
    console.log("[*] Автоопределение версии EDT через ring...");
    const ringList = execSync('ring --list', { encoding: 'utf-8' });
    const match = ringList.match(/edt@\S+/);
    if (match) {
      edtVersion = match[0];
      console.log(`[+] Найдена установленная версия EDT: ${edtVersion}`);
    } else {
      throw new Error("EDT не зарегистрирован в ring");
    }
  } catch (err) {
    console.warn("[-] Не удалось автоопределить EDT через ring. Используем дефолтный edt@2025.2.0");
    edtVersion = "edt@2025.2.0";
  }
}

// 3. Создание временного рабочего пространства для экспорта метаданных
const runId = Date.now();
const tempWorkspace = path.join(os.tmpdir(), `edt_ws_${runId}`);
const tempXmlDir = path.join(os.tmpdir(), `edt_xml_${runId}`);
const tempDbDir = path.join(os.tmpdir(), `1c_temp_db_${runId}`);

fs.mkdirSync(tempWorkspace, { recursive: true });
fs.mkdirSync(tempXmlDir, { recursive: true });

try {
  // 4. Шаг 1: Трансляция структуры проекта EDT в классический XML-формат
  console.log("[*] Шаг 1: Экспорт исходного кода проекта EDT в XML-схему...");
  const exportCmd = `ring ${edtVersion} workspace export --workspace "${tempWorkspace}" --project "${extensionName}" --configuration "${tempXmlDir}"`;
  execSync(exportCmd, { stdio: 'inherit' });

  // 5. Шаг 2: Создание временной файловой базы 1С для упаковки бинарника
  console.log("[*] Шаг 2: Создание временной ИБ для компиляции метаданных...");
  const isWindows = os.platform() === 'win32';
  const path1C = isWindows 
    ? '"C:\Program Files\1cv8\common\1cv8.exe"' 
    : '/opt/1cv8/x86_64/current/1cv8';

  const createDbCmd = `${path1C} CREATEINFOBASE File="${tempDbDir}" /Out /dev/null`;
  execSync(createDbCmd, { stdio: 'inherit' });

  // 6. Шаг 3: Импорт XML во временную базу и выгрузка готового .cfe файла
  console.log("[*] Шаг 3: Пакетный импорт исходников и сборка бинарного файла...");
  const outputDir = path.dirname(absoluteOutput);
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  // Сборка расширения
  const importArgs = `DESIGNER /F"${tempDbDir}" /N "Admin" /LoadConfigFromFiles "${tempXmlDir}" -Extension "${extensionName}" /UpdateDBCfg /SaveConfigFile "${absoluteOutput}" -Extension "${extensionName}" /Out /tmp/compile_out_${runId}.txt`;
  
  const fullCmd = isWindows ? `${path1C} ${importArgs}` : `xvfb-run -a ${path1C} ${importArgs}`;
  execSync(fullCmd, { stdio: 'inherit' });

  if (fs.existsSync(absoluteOutput) && fs.statSync(absoluteOutput).size > 0) {
    console.log(`[+] Сборка успешно завершена! Файл сохранен: ${absoluteOutput}`);
  } else {
    throw new Error("Итоговый файл .cfe не был сформирован или пуст.");
  }

} catch (err) {
  console.error("[-] Процесс конвертации и сборки завершился ошибкой:", err.message);
  process.exit(1);
} finally {
  // Гарантированная зачистка временных ресурсов
  console.log("[*] Зачистка временных каталогов...");
  fs.rmSync(tempWorkspace, { recursive: true, force: true });
  fs.rmSync(tempXmlDir, { recursive: true, force: true });
  fs.rmSync(tempDbDir, { recursive: true, force: true });
  if (fs.existsSync(`/tmp/compile_out_${runId}.txt`)) {
    fs.unlinkSync(`/tmp/compile_out_${runId}.txt`);
  }
}
