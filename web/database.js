const DB_NAME='altafawuq-local',DB_VERSION=2;
const STORES={
 settings:{keyPath:'key'},
 grades:{keyPath:'id'},
 studyTracks:{keyPath:'id',indexes:[['gradeId','gradeId']]},
 subjects:{keyPath:'id',indexes:[['gradeId','gradeId'],['trackId','trackId']]},
 curriculumReleases:{keyPath:'id',indexes:[['gradeId','gradeId']]},
 releaseSubjects:{keyPath:'id',indexes:[['releaseId','releaseId'],['subjectId','subjectId']]},
 units:{keyPath:'id',indexes:[['subjectId','subjectId'],['packageId','packageId']]},
 lessons:{keyPath:'id',indexes:[['unitId','unitId']]},
 exams:{keyPath:'id',indexes:[['subjectId','subjectId'],['packageId','packageId']]},
 questions:{keyPath:'id',indexes:[['subjectId','subjectId'],['packageId','packageId']]},
 examQuestions:{keyPath:['examId','questionId'],indexes:[['examId','examId']]},
 attempts:{keyPath:'id',indexes:[['examId','examId']]},
 attemptAnswers:{keyPath:['attemptId','questionId'],indexes:[['attemptId','attemptId']]},
 bookmarks:{keyPath:'id'},
 progress:{keyPath:'lessonId'},
 profiles:{keyPath:'id'},
 contentPackages:{keyPath:'code'},
 packageReviews:{keyPath:'id',indexes:[['packageId','packageId']]},
 sessions:{keyPath:'id',indexes:[['startedAt','startedAt'],['subjectId','subjectId']]}
};
export function openDb(){return new Promise((resolve,reject)=>{const req=indexedDB.open(DB_NAME,DB_VERSION);req.onupgradeneeded=()=>{const db=req.result;for(const [name,spec] of Object.entries(STORES)){let store;if(!db.objectStoreNames.contains(name))store=db.createObjectStore(name,{keyPath:spec.keyPath});else store=req.transaction.objectStore(name);for(const [index,key] of spec.indexes||[])if(!store.indexNames.contains(index))store.createIndex(index,key,{unique:false});}const tx=req.transaction;const grades=tx.objectStore('grades');for(const row of [{id:1,code:'secondary_1',name:'الصف الأول الثانوي',sortOrder:1,active:true},{id:2,code:'secondary_2',name:'الصف الثاني الثانوي',sortOrder:2,active:true},{id:3,code:'secondary_3',name:'الصف الثالث الثانوي',sortOrder:3,active:true}])grades.put(row);};req.onsuccess=()=>resolve(req.result);req.onerror=()=>reject(req.error);});}
export async function transact(storeName,mode,operation){const db=await openDb();return new Promise((resolve,reject)=>{const tx=db.transaction(storeName,mode);let result;try{result=operation(tx.objectStore(storeName));}catch(error){db.close();reject(error);return;}tx.oncomplete=()=>{db.close();resolve(result)};tx.onerror=()=>{const error=tx.error;db.close();reject(error)};tx.onabort=()=>{const error=tx.error;db.close();reject(error||new Error('Database transaction aborted'));};});}
export async function getRecord(store,key){const db=await openDb();return new Promise((resolve,reject)=>{const tx=db.transaction(store,'readonly'),req=tx.objectStore(store).get(key);req.onsuccess=()=>{const value=req.result;db.close();resolve(value)};req.onerror=()=>{const error=req.error;db.close();reject(error)};});}
export async function getAll(store){const db=await openDb();return new Promise((resolve,reject)=>{const tx=db.transaction(store,'readonly'),req=tx.objectStore(store).getAll();req.onsuccess=()=>{const value=req.result;db.close();resolve(value)};req.onerror=()=>{const error=req.error;db.close();reject(error)};});}
export async function saveRecord(store,value){return transact(store,'readwrite',s=>s.put(value));}
export async function getStudentProfile(){return getRecord('profiles',1);}
export async function saveStudentProfile({name,gradeId,trackId=null}){const grade=await getRecord('grades',Number(gradeId));if(!grade||!grade.active)throw new Error('الصف الدراسي غير صالح');if(trackId!==null){const track=await getRecord('studyTracks',Number(trackId));if(!track||track.gradeId!==Number(gradeId)||!track.active)throw new Error('المسار لا يتبع الصف المختار');}return saveRecord('profiles',{id:1,name:(name||'').trim()||null,gradeId:Number(gradeId),trackId:trackId===null?null:Number(trackId),updatedAt:new Date().toISOString()});}
export async function getTracksForGrade(gradeId){return (await getAll('studyTracks')).filter(t=>t.gradeId===Number(gradeId)&&t.active!==false).sort((a,b)=>(a.name||'').localeCompare(b.name||'','ar'));}
export async function getPublishedUnits({gradeId,trackId=null,subjectId=null}){const [units,subjects,releases,releaseSubjects,packages]=await Promise.all(['units','subjects','curriculumReleases','releaseSubjects','contentPackages'].map(getAll));const sm=new Map(subjects.map(x=>[x.id,x])),rm=new Map(releases.map(x=>[x.id,x])),rsm=new Map(releaseSubjects.map(x=>[x.id,x])),pm=new Map(packages.map(x=>[x.id,x]));return units.filter(u=>{const s=sm.get(u.subjectId),rs=rsm.get(u.releaseSubjectId),r=rs&&rm.get(rs.releaseId),p=pm.get(u.packageId);return s&&s.gradeId===Number(gradeId)&&(trackId===null?s.trackId==null:(s.trackId==null||s.trackId===Number(trackId)))&&(!subjectId||s.id===Number(subjectId))&&rs?.verificationStatus==='verified'&&r?.verificationStatus==='verified'&&p?.reviewStatus==='approved';}).map(u=>({...u,subjectName:sm.get(u.subjectId)?.name})).sort((a,b)=>(a.subjectName||'').localeCompare(b.subjectName||'','ar')||(a.sortOrder||0)-(b.sortOrder||0));}
