alter table org_usersec_link drop constraint "org_usersec_link_us_fk";


alter table org_usersec_link
  add Constraint org_usersec_link_us_fk foreign key(us_fk) references
  usersec(us_pk) on delete cascade;



alter table study add column study_url text;
alter table study add column tree_fk integer;
alter table study add constraint study_tree_fk foreign key(tree_fk)
  references tree(tree_pk);


CREATE TABLE "disease" (
  "dis_pk" integer DEFAULT nextval('filetypes_ft_pk_seq'::text) NOT
  NULL,
  "dis_name" character varying(256),
  Constraint dis_pkey primary key(dis_pk)
) without OIDs;

CREATE TABLE "disease_study_link" (
  "dis_fk" integer,
  "sty_fk" integer,
  Constraint disease_study_link_dis_fk foreign key(dis_fk)
     references disease(dis_pk),
  Constraint disease_study_link_sty_fk foreign key(sty_fk)
     references study(sty_pk) on delete cascade 
) without OIDs;

INSERT INTO disease (dis_name) values ('Acute Lymphoblastic Leukemia');
INSERT INTO disease (dis_name) values('Acute Myelogenous Leukemia');
INSERT INTO disease (dis_name) values('Adrenocortical Carcinoma');
INSERT INTO disease (dis_name) values('Astrocytoma');
INSERT INTO disease (dis_name) values('Atypical Teratoid/Rhabdoid Tum');
INSERT INTO disease (dis_name) values('Bladder Carcinoma');
INSERT INTO disease (dis_name) values('Breast Carcinoma');
INSERT INTO disease (dis_name) values('Burkitt Lymphoma');
INSERT INTO disease (dis_name) values('Chronic Lymphocytic Leukemia');
INSERT INTO disease (dis_name) values('Colon Adenocarcinoma');
INSERT INTO disease (dis_name) values('Cutaneous Diffuse Large B-Cell');
INSERT INTO disease (dis_name) values('Cutaneous Follicular Lymphoma');
INSERT INTO disease (dis_name) values('Diffuse Large B-Cell Lymphoma');
INSERT INTO disease (dis_name) values('Endometrial Adenocarcinoma');
INSERT INTO disease (dis_name) values('Ewing Sarcoma');
INSERT INTO disease (dis_name) values('Follicular Lymphoma');
INSERT INTO disease (dis_name) values('Gastroesophageal Adenocarcinom');
INSERT INTO disease (dis_name) values('Gastrointestinal Stromal Tumor');
INSERT INTO disease (dis_name) values('Glioblastoma Multiforme');
INSERT INTO disease (dis_name) values('Glioma');
INSERT INTO disease (dis_name) values('Hepatocellular Carcinoma');
INSERT INTO disease (dis_name) values('Large Cell Lung Cancer');
INSERT INTO disease (dis_name) values('Leiomyosarcoma');
INSERT INTO disease (dis_name) values('Leukemia');
INSERT INTO disease (dis_name) values('Liposarcoma');
INSERT INTO disease (dis_name) values('Liver Metastasis');
INSERT INTO disease (dis_name) values('Lung Adenocarcinoma');
INSERT INTO disease (dis_name) values('Lung Carcinoid');
INSERT INTO disease (dis_name) values('Lung Carcinoma');
INSERT INTO disease (dis_name) values('Malignant Fibrous Histiocytoma');
INSERT INTO disease (dis_name) values('Mantle Cell Lymphoma');
INSERT INTO disease (dis_name) values('Marginal Zone Lymphoma');
INSERT INTO disease (dis_name) values('Medulloblastoma');
INSERT INTO disease (dis_name) values('Melanoma');
INSERT INTO disease (dis_name) values('Melanoma of Soft Parts');
INSERT INTO disease (dis_name) values('Meningioma');
INSERT INTO disease (dis_name) values('Mixed Lineage Leukemia');
INSERT INTO disease (dis_name) values('Monophasic Synovial Sarcoma');
INSERT INTO disease (dis_name) values('Neuroblastoma');
INSERT INTO disease (dis_name) values('Other');
INSERT INTO disease (dis_name) values('Ovarian Carcinoma');
INSERT INTO disease (dis_name) values('Pancreatic Adenocarcinoma');
INSERT INTO disease (dis_name) values('Pleural Mesothelioma');
INSERT INTO disease (dis_name) values('Primitive Neuroectodermal
Tumor');
INSERT INTO disease (dis_name) values('Prostate Adenocarcinoma');
INSERT INTO disease (dis_name) values('Renal Cell Carcinoma');
INSERT INTO disease (dis_name) values('Rhabdomyosarcoma');
INSERT INTO disease (dis_name) values('Salivary Carcinoma');
INSERT INTO disease (dis_name) values('Small Cell Lung Cancer');
INSERT INTO disease (dis_name) values('Soft Tissue Sarcoma');
INSERT INTO disease (dis_name) values('Squamous Cell Lung Carcinoma');
INSERT INTO disease (dis_name) values('T-Cell Acute Lymphoblastic
Leukemia');
INSERT INTO disease (dis_name) values('Thyroid Carcinoma');
INSERT INTO disease (dis_name) values('Alzheimers');
INSERT INTO disease (dis_name) values('Cystic Fibrosis');
INSERT INTO disease (dis_name) values('Stem Cell Research');


alter table study add column "study_abstract" text;

update user_parameter_names
  set up_display_name='First Filtering:' 
  where up_display_name=' <br>First Filtering:';
update user_parameter_names
  set up_display_name='(Optional) differential discovery by:'
  where up_display_name=' <br> (Optional) differential discovery by:';
update user_parameter_names
  set up_display_name='Intermediate data filename (no extension)'
  where up_display_name=' <br>Intermediate data filename (no extension)';
update user_parameter_names
  set up_display_name='Select two conditions to compare:'
  where up_display_name like '%Select two conditions to compare%';

update user_parameter_names
  set up_display_name='Functional Filtering'
  where up_display_name=' <b>Functional Filtering</b>:';

update analysis set current = 'f' where an_name='Quality Control' 
   and version='1';

update analysis set current = 'f' where an_name='Differential Discovery'
   and version='2';

update analysis set current = 'f' where an_name='Filter' and
   version='2';

update analysis set current = 'f' where an_name='Cluster' and
   version='1';
