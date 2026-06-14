import 'main.dart';

// Complete list of 70+ simple tense forms of "Fazer"
const List<VerbForm> fazerFormsList = [
  // --- INDICATIVO ---
  // Presente
  VerbForm("faço", "1st pres. indic."),
  VerbForm("fazes", "2nd pres. indic."),
  VerbForm("faz", "3rd pres. indic."),
  VerbForm("fazemos", "1st pl. pres. indic."),
  VerbForm("fazeis", "2nd pl. pres. indic."),
  VerbForm("fazem", "3rd pl. pres. indic."),
  // Pretérito Perfeito
  VerbForm("fiz", "1st pret. perf. indic."),
  VerbForm("fizeste", "2nd pret. perf. indic."),
  VerbForm("fez", "3rd pret. perf. indic."),
  VerbForm("fizemos", "1st pl. pret. perf. indic."),
  VerbForm("fizestes", "2nd pl. pret. perf. indic."),
  VerbForm("fizeram", "3rd pl. pret. perf. indic."),
  // Pretérito Imperfeito
  VerbForm("fazia", "1st pret. imperf. indic."),
  VerbForm("fazias", "2nd pret. imperf. indic."),
  VerbForm("fazia", "3rd pret. imperf. indic."),
  VerbForm("fazíamos", "1st pl. pret. imperf. indic."),
  VerbForm("fazíeis", "2nd pl. pret. imperf. indic."),
  VerbForm("faziam", "3rd pl. pret. imperf. indic."),
  // Pretérito Mais-que-Perfeito
  VerbForm("fizera", "1st m-q-perf. indic."),
  VerbForm("fizeras", "2nd m-q-perf. indic."),
  VerbForm("fizera", "3rd m-q-perf. indic."),
  VerbForm("fizéramos", "1st pl. m-q-perf. indic."),
  VerbForm("fizéreis", "2nd pl. m-q-perf. indic."),
  VerbForm("fizeram", "3rd pl. m-q-perf. indic."),
  // Futuro do Presente
  VerbForm("farei", "1st fut. pres. indic."),
  VerbForm("farás", "2nd fut. pres. indic."),
  VerbForm("fará", "3rd fut. pres. indic."),
  VerbForm("faremos", "1st pl. fut. pres. indic."),
  VerbForm("fareis", "2nd pl. fut. pres. indic."),
  VerbForm("farão", "3rd pl. fut. pres. indic."),
  // Futuro do Pretérito (Condicional)
  VerbForm("faria", "1st fut. pret. indic."),
  VerbForm("farias", "2nd fut. pret. indic."),
  VerbForm("faria", "3rd fut. pret. indic."),
  VerbForm("faríamos", "1st pl. fut. pret. indic."),
  VerbForm("faríeis", "2nd pl. fut. pret. indic."),
  VerbForm("fariam", "3rd pl. fut. pret. indic."),

  // --- SUBJUNTIVO ---
  // Presente
  VerbForm("faça", "1st pres. subj."),
  VerbForm("faças", "2nd pres. subj."),
  VerbForm("faça", "3rd pres. subj."),
  VerbForm("façamos", "1st pl. pres. subj."),
  VerbForm("façais", "2nd pl. pres. subj."),
  VerbForm("façam", "3rd pl. pres. subj."),
  // Imperfeito
  VerbForm("fizesse", "1st imperf. subj."),
  VerbForm("fizesses", "2nd imperf. subj."),
  VerbForm("fizesse", "3rd imperf. subj."),
  VerbForm("fizéssemos", "1st pl. imperf. subj."),
  VerbForm("fizésseis", "2nd pl. imperf. subj."),
  VerbForm("fizessem", "3rd pl. imperf. subj."),
  // Futuro
  VerbForm("fizer", "1st fut. subj."),
  VerbForm("fizeres", "2nd fut. subj."),
  VerbForm("fizer", "3rd fut. subj."),
  VerbForm("fizermo", "1st pl. fut. subj."),
  VerbForm("fizerdes", "2nd pl. fut. subj."),
  VerbForm("fizerem", "3rd pl. fut. subj."),

  // --- IMPERATIVO ---
  VerbForm("faze", "2nd imperat. afirm."), // ou faz
  VerbForm("faça", "3rd imperat. afirm."),
  VerbForm("façamos", "1st pl. imperat. afirm."),
  VerbForm("fazei", "2nd pl. imperat. afirm."),
  VerbForm("façam", "3rd pl. imperat. afirm."),

  // --- INFINITIVO PESSOAL ---
  VerbForm("fazer", "1st inf. pessoal"),
  VerbForm("fazeres", "2nd inf. pessoal"),
  VerbForm("fazer", "3rd inf. pessoal"),
  VerbForm("fazermos", "1st pl. inf. pessoal"),
  VerbForm("fazerdes", "2nd pl. inf. pessoal"),
  VerbForm("fazerem", "3rd pl. inf. pessoal"),

  // --- FORMAS NOMINAIS ---
  VerbForm("fazer", "inf. impessoal"),
  VerbForm("fazendo", "gerúndio"),
  VerbForm("feito", "particípio"),
];
