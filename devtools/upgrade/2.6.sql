drop INDEX arraymeasurement_hybridization_name_ind ;

create INDEX arraymeasurement_hybridization_name_ind on arraymeasurement
(hybridization_name);


alter table configuration add column "array_center" boolean;
alter table configuration alter "array_center" set default true;
alter table configuration add column "analysis" boolean;
alter table configuration alter "analysis" set default true;
alter table configuration add column "data_publishing" boolean;
alter table configuration alter "data_publishing" set default true;
alter table configuration add column "user_data_load" boolean;
alter table configuration alter "user_data_load" set default false;
alter table configuration add column "ord_num_format" varchar(128);
alter table configuration alter "ord_num_format" set default 'year sequential';

alter table study add column "default_exp_cond_name" character varying(128);
alter table study add column "default_spc_fk" integer;
alter table study add column "default_sample_type" character varying(128);
alter table study add column "default_type_details" character varying(128);
alter table study add column "default_bio_reps" integer DEFAULT 1 NOT NULL;
alter table study add column "default_chip_reps" integer DEFAULT 1 NOT NULL;
alter table study add column "default_smp_name" character varying(128);
alter table study add column "default_lab_book" character varying(128);
alter table study add column "default_lab_book_owner" integer;
alter table study add column "default_smp_origin" text;
alter table study add column "default_smp_manipulation" text;
alter table study add column "default_al_fk" integer;

alter table order_info alter column order_number drop not null;

update analysis set current = 'f' where an_name = 'Cluster' and version
= '2';
update analysis set current = 'f' where an_name = 'Differential Discovery'
 and version = '3';
update analysis set current = 'f' where an_name = 'Filter' and version
= '3';
update analysis set current = 'f' where an_name = 'Classification' and version
= '2';
update analysis set current = 'f' where an_name = 'Quality Control' and version
= '2';
update analysis set current = 'f' where an_name = 
'Multi-Condition Filter' and version ='1';
update analysis set current = 'f' where an_name = 
'Multi-Condition Differential Discovery' and version ='1';
