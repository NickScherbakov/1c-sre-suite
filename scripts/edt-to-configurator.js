// ==============================================================================
// CLI-СѓС‚РёР»РёС‚Р° Рё Agent Skill: Р‘РµСЃС€РѕРІРЅС‹Р№ РјРѕСЃС‚ РёР· 1C:EDT РІ РљРѕРЅС„РёРіСѓСЂР°С‚РѕСЂ
// ==============================================================================
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const os = require('os');

// Р”РµРєР»Р°СЂР°С‚РёРІРЅРѕРµ РѕРїРёСЃР°РЅРёРµ СЃРєРёР»Р»Р° РґР»СЏ РР-Р°РіРµРЅС‚РѕРІ (РїРѕ СЃРїРµС†РёС„РёРєР°С†РёРё Agent Skills)
const SKILL_METADATA = {
  name: "edt_to_configurator",
  description: "РђРІС‚РѕРјР°С‚РёС‡РµСЃРєРё С‚СЂР°РЅСЃР»РёСЂСѓРµС‚ С‚РµРєСЃС‚РѕРІС‹Рµ РёСЃС…РѕРґРЅС‹Рµ РєРѕРґС‹ РїСЂРѕРµРєС‚РѕРІ 1C:EDT РІ Р±РёРЅР°СЂРЅС‹Рµ С„РѕСЂРјР°С‚С‹ РљРѕРЅС„РёРіСѓСЂР°С‚РѕСЂР° (.cf/.cfe) РЅР° Windows Рё Linux",
  arguments: {
    projectDir: "РџСѓС‚СЊ Рє РєРѕСЂРЅСЋ РїСЂРѕРµРєС‚Р° EDT (РіРґРµ Р»РµР¶РёС‚ .project Рё src/)",
    output: "РђР±СЃРѕР»СЋС‚РЅС‹Р№ РїСѓС‚СЊ РґР»СЏ СЃРѕС…СЂР°РЅРµРЅРёСЏ Р±РёРЅР°СЂРЅРѕРіРѕ .cfe РёР»Рё .cf",
    edtVersion: "РљРѕРЅРєСЂРµС‚РЅР°СЏ РІРµСЂСЃРёСЏ EDT РґР»СЏ Р·Р°РїСѓСЃРєР° С‡РµСЂРµР· ring (РЅР°РїСЂРёРјРµСЂ, edt@2025.2.0)"
  }
};

const args = process.argv.slice(2);
const command = args[0];

if (command !== "convert") {
  console.log("РЈРєР°Р¶РёС‚Рµ РєРѕРјР°РЅРґСѓ 'convert' Рё Р°СЂРіСѓРјРµРЅС‚С‹:");
  console.log("node edt-to-configurator.js convert --projectDir <path> --output <file.cfe>");
  process.exit(1);
}

// РџСЂРѕСЃС‚РѕР№ РїР°СЂСЃРёРЅРі Р°СЂРіСѓРјРµРЅС‚РѕРІ РєРѕРјР°РЅРґРЅРѕР№ СЃС‚СЂРѕРєРё
const getArg = (flag) => {
  const index = args.indexOf(flag);
  return (index !== -1 && args[index + 1]) ? args[index + 1] : null;
};

const projectDir = getArg("--projectDir");
const output = getArg("--output");
let edtVersion = getArg("--edtVersion");

if (!projectDir || !output) {
  console.error("[-] РћС€РёР±РєР°: РћС‚СЃСѓС‚СЃС‚РІСѓСЋС‚ РѕР±СЏР·Р°С‚РµР»СЊРЅС‹Рµ РїР°СЂР°РјРµС‚СЂС‹ --projectDir Рё/РёР»Рё --output");
  process.exit(1);
}

const absoluteProjDir = path.resolve(projectDir);
const absoluteOutput = path.resolve(output);

// 1. РР·РІР»РµС‡РµРЅРёРµ РёРјРµРЅРё СЂР°СЃС€РёСЂРµРЅРёСЏ/РїСЂРѕРµРєС‚Р° РёР· .project
const projectFilePath = path.join(absoluteProjDir, '.project');
if (!fs.existsSync(projectFilePath)) {
  console.error(`[-] РћС€РёР±РєР°: Р’ СѓРєР°Р·Р°РЅРЅРѕРј РєР°С‚Р°Р»РѕРіРµ РѕС‚СЃСѓС‚СЃС‚РІСѓРµС‚ СЃР»СѓР¶РµР±РЅС‹Р№ С„Р°Р№Р» EDT: ${projectFilePath}`);
  process.exit(1);
}

const projectFileContent = fs.readFileSync(projectFilePath, 'utf-8');
const nameMatch = projectFileContent.match(/<name>(.*?)<\/name>/);
const extensionName = nameMatch ? nameMatch[1] : "TemporaryBuildExtension";
console.log(`[*] РћР±РЅР°СЂСѓР¶РµРЅРѕ РёРјСЏ РїСЂРѕРµРєС‚Р° EDT: ${extensionName}`);

// 2. РђРІС‚РѕРѕРїСЂРµРґРµР»РµРЅРёРµ СѓСЃС‚Р°РЅРѕРІР»РµРЅРЅРѕР№ РІРµСЂСЃРёРё EDT РІ СЂРµРµСЃС‚СЂРµ ring
if (!edtVersion) {
  try {
    console.log("[*] РђРІС‚РѕРѕРїСЂРµРґРµР»РµРЅРёРµ РІРµСЂСЃРёРё EDT С‡РµСЂРµР· ring...");
    const ringList = execSync('ring --list', { encoding: 'utf-8' });
    const match = ringList.match(/edt@\S+/);
    if (match) {
      edtVersion = match[0];
      console.log(`[+] РќР°Р№РґРµРЅР° СѓСЃС‚Р°РЅРѕРІР»РµРЅРЅР°СЏ РІРµСЂСЃРёСЏ EDT: ${edtVersion}`);
    } else {
      throw new Error("EDT РЅРµ Р·Р°СЂРµРіРёСЃС‚СЂРёСЂРѕРІР°РЅ РІ ring");
    }
  } catch (err) {
    console.warn("[-] РќРµ СѓРґР°Р»РѕСЃСЊ Р°РІС‚РѕРѕРїСЂРµРґРµР»РёС‚СЊ EDT С‡РµСЂРµР· ring. РСЃРїРѕР»СЊР·СѓРµРј РґРµС„РѕР»С‚РЅС‹Р№ edt@2025.2.0");
    edtVersion = "edt@2025.2.0";
  }
}

// 3. РЎРѕР·РґР°РЅРёРµ РІСЂРµРјРµРЅРЅРѕРіРѕ СЂР°Р±РѕС‡РµРіРѕ РїСЂРѕСЃС‚СЂР°РЅСЃС‚РІР° РґР»СЏ СЌРєСЃРїРѕСЂС‚Р° РјРµС‚Р°РґР°РЅРЅС‹С…
const runId = Date.now();
const tempWorkspace = path.join(os.tmpdir(), `edt_ws_${runId}`);
const tempXmlDir = path.join(os.tmpdir(), `edt_xml_${runId}`);
const tempDbDir = path.join(os.tmpdir(), `1c_temp_db_${runId}`);

fs.mkdirSync(tempWorkspace, { recursive: true });
fs.mkdirSync(tempXmlDir, { recursive: true });

try {
  // 4. РЁР°Рі 1: РўСЂР°РЅСЃР»СЏС†РёСЏ СЃС‚СЂСѓРєС‚СѓСЂС‹ РїСЂРѕРµРєС‚Р° EDT РІ РєР»Р°СЃСЃРёС‡РµСЃРєРёР№ XML-С„РѕСЂРјР°С‚
  console.log("[*] РЁР°Рі 1: Р­РєСЃРїРѕСЂС‚ РёСЃС…РѕРґРЅРѕРіРѕ РєРѕРґР° РїСЂРѕРµРєС‚Р° EDT РІ XML-СЃС…РµРјСѓ...");
  const exportCmd = `ring ${edtVersion} workspace export --workspace "${tempWorkspace}" --project "${extensionName}" --configuration "${tempXmlDir}"`;
  execSync(exportCmd, { stdio: 'inherit' });

  // 5. РЁР°Рі 2: РЎРѕР·РґР°РЅРёРµ РІСЂРµРјРµРЅРЅРѕР№ С„Р°Р№Р»РѕРІРѕР№ Р±Р°Р·С‹ 1РЎ РґР»СЏ СѓРїР°РєРѕРІРєРё Р±РёРЅР°СЂРЅРёРєР°
  console.log("[*] РЁР°Рі 2: РЎРѕР·РґР°РЅРёРµ РІСЂРµРјРµРЅРЅРѕР№ РР‘ РґР»СЏ РєРѕРјРїРёР»СЏС†РёРё РјРµС‚Р°РґР°РЅРЅС‹С…...");
  const isWindows = os.platform() === 'win32';
  const path1C = isWindows 
    ? '"C:\Program Files\1cv8\common\1cv8.exe"' 
    : '/opt/1cv8/x86_64/current/1cv8';

  const createDbCmd = `${path1C} CREATEINFOBASE File="${tempDbDir}" /Out /dev/null`;
  execSync(createDbCmd, { stdio: 'inherit' });

  // 6. РЁР°Рі 3: РРјРїРѕСЂС‚ XML РІРѕ РІСЂРµРјРµРЅРЅСѓСЋ Р±Р°Р·Сѓ Рё РІС‹РіСЂСѓР·РєР° РіРѕС‚РѕРІРѕРіРѕ .cfe С„Р°Р№Р»Р°
  console.log("[*] РЁР°Рі 3: РџР°РєРµС‚РЅС‹Р№ РёРјРїРѕСЂС‚ РёСЃС…РѕРґРЅРёРєРѕРІ Рё СЃР±РѕСЂРєР° Р±РёРЅР°СЂРЅРѕРіРѕ С„Р°Р№Р»Р°...");
  const outputDir = path.dirname(absoluteOutput);
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  // РЎР±РѕСЂРєР° СЂР°СЃС€РёСЂРµРЅРёСЏ
  const importArgs = `DESIGNER /F"${tempDbDir}" /N "Admin" /LoadConfigFromFiles "${tempXmlDir}" -Extension "${extensionName}" /UpdateDBCfg /SaveConfigFile "${absoluteOutput}" -Extension "${extensionName}" /Out /tmp/compile_out_${runId}.txt`;
  
  const fullCmd = isWindows ? `${path1C} ${importArgs}` : `xvfb-run -a ${path1C} ${importArgs}`;
  execSync(fullCmd, { stdio: 'inherit' });

  if (fs.existsSync(absoluteOutput) && fs.statSync(absoluteOutput).size > 0) {
    console.log(`[+] РЎР±РѕСЂРєР° СѓСЃРїРµС€РЅРѕ Р·Р°РІРµСЂС€РµРЅР°! Р¤Р°Р№Р» СЃРѕС…СЂР°РЅРµРЅ: ${absoluteOutput}`);
  } else {
    throw new Error("РС‚РѕРіРѕРІС‹Р№ С„Р°Р№Р» .cfe РЅРµ Р±С‹Р» СЃС„РѕСЂРјРёСЂРѕРІР°РЅ РёР»Рё РїСѓСЃС‚.");
  }

} catch (err) {
  console.error("[-] РџСЂРѕС†РµСЃСЃ РєРѕРЅРІРµСЂС‚Р°С†РёРё Рё СЃР±РѕСЂРєРё Р·Р°РІРµСЂС€РёР»СЃСЏ РѕС€РёР±РєРѕР№:", err.message);
  process.exit(1);
} finally {
  // Р“Р°СЂР°РЅС‚РёСЂРѕРІР°РЅРЅР°СЏ Р·Р°С‡РёСЃС‚РєР° РІСЂРµРјРµРЅРЅС‹С… СЂРµСЃСѓСЂСЃРѕРІ
  console.log("[*] Р—Р°С‡РёСЃС‚РєР° РІСЂРµРјРµРЅРЅС‹С… РєР°С‚Р°Р»РѕРіРѕРІ...");
  fs.rmSync(tempWorkspace, { recursive: true, force: true });
  fs.rmSync(tempXmlDir, { recursive: true, force: true });
  fs.rmSync(tempDbDir, { recursive: true, force: true });
  if (fs.existsSync(`/tmp/compile_out_${runId}.txt`)) {
    fs.unlinkSync(`/tmp/compile_out_${runId}.txt`);
  }
}
