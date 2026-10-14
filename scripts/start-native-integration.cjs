const path = require('node:path');
const fs = require('node:fs');
// Pass the backend repository folder as the first argument when it is not a sibling.
const project = path.resolve(process.argv[2] || path.join(__dirname, '..', '..', 'chettinad-care-frontend'));
const fixture = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'chettinad-native-fixture-'));
// The folder is created exclusively for this process; no existing database is touched.
process.on('exit', () => fs.rmSync(fixture, { recursive: true, force: true }));
Object.assign(process.env, {
  NODE_ENV:'test', APP_ENV:'local_dev', DB_DIALECT:'sqlite', SQLITE_PATH:path.join(fixture,'validation.db'),
  PATIENT_DOCUMENT_STORAGE_PATH:path.join(fixture,'documents'), OPD_DEMO_OTP:'true',
  OTP_COOLDOWN_SECONDS:'1', OPD_NOTIFICATION_WORKER:'false', ENABLE_LEGACY_API:'false', OPD_OG_PILOT_ONLY:'true',
  JWT_SECRET:'SyntheticNativeIntegrationSecret2026Only', BOOTSTRAP_ADMIN_ID:'native_admin',
  BOOTSTRAP_ADMIN_NAME:'Synthetic Administrator', BOOTSTRAP_ADMIN_PASSWORD:'NativeIntegration2026!'
});
const app = require(path.join(project,'backend/server.js'));
const db = require(path.join(project,'backend/database.js'));
const bcrypt = require(path.join(project,'backend/node_modules/bcryptjs'));
(async()=>{
  await db.migrateDatabase();
  await require(path.join(project,'backend/bootstrapAdmin.js')).ensureBootstrapAdmin(db);
  const dept=await db.get("SELECT * FROM departments WHERE prefix='OBST'");
  const hash=await bcrypt.hash('NativeIntegration2026!',12);
  for (const [id,role,name] of [['native_doctor','DOCTOR','Synthetic Doctor'],['native_nurse','NURSE','Synthetic Nurse'],['native_first_login','DOCTOR','Synthetic New Doctor']]) {
    await db.run('INSERT INTO users (id,name,role,department,password_hash,must_change_password,is_active,created_at,updated_at) VALUES (?,?,?,?,?,?,1,?,?)',[id,name,role,dept.name,hash,id === 'native_first_login' ? 1 : 0,new Date().toISOString(),new Date().toISOString()]);
  }
  for(const [id,phone] of [['native_patient_a','+919100000991'],['native_patient_b','+919100000992']]) {
    await db.run('INSERT INTO patients (id,mrn,name,phone,dob,gender) VALUES (?,?,?,?,?,?)',[id,'SYN-'+id,'Synthetic '+id,phone,'1995-01-01','Female']);
    await db.run('INSERT INTO users (id,name,role,patient_id,is_active,must_change_password) VALUES (?,?,\'PATIENT\',?,1,0)',[id+'_user','Synthetic '+id,id]);
  }
  for(let weekday=0;weekday<7;weekday++) {
    await db.run('INSERT INTO practitioner_schedules (id,doctor_id,department_id,weekday,start_time,end_time,slot_minutes,room) VALUES (?,?,?,?,?,?,?,?)',['native_schedule_'+weekday,'native_doctor',dept.id,weekday,'00:00','23:59',5,'Synthetic OPD']);
  }
  await db.run("INSERT INTO drug_catalog (id,name,strength,form,route,active) VALUES ('native_drug','Synthetic Medicine','1 unit','Tablet','Oral',1)");
  await db.run("INSERT INTO diagnosis_catalog (id,name) VALUES ('native_diagnosis','Synthetic Assessment')");
  const server=app.listen(3011,'127.0.0.1',()=>console.log('NATIVE_FIXTURE_READY http://127.0.0.1:3011 (isolated SQLite; synthetic data only)'));
  process.once('SIGTERM',()=>server.close(()=>db.db.close(()=>process.exit(0))));
})().catch(error=>{console.error(error);process.exit(1)});
