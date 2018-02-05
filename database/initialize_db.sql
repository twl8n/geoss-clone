
--
-- PostgreSQL database dump
--

SET search_path = public, pg_catalog;

--
-- Data for TOC entry 1 (OID 17268)
-- Name: dic_contacttype; Type: TABLE DATA; Schema: public; Owner: geoss
--


insert into dic_contacttype (term_string, description) values ('member_user','information is being provided about the source of the experiment set.');

insert into dic_contacttype (term_string, description) values ('array_center_starff','an employee of the array center who runs chips and loads data');

insert into dic_contacttype (term_string, description) values ('developer','a developer on the GEOSS project');

insert into dic_contacttype (term_string, description) values ('public_user','an unverified  GEOSS user');

insert into dic_contacttype (term_string, description) values ('administrator','a user responsible for administration of GEOSS');

--
-- PostgreSQL database dump
--

SET search_path = public, pg_catalog;

--
-- Data for TOC entry 1 (OID 17238)
-- Name: species; Type: TABLE DATA; Schema: public; Owner: geoss
--

insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('89','Lycopodium clavatum','f','f',null,'plant:bryophyte',null,'stag\'s-horn clubmoss',null,null,'3252','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Tree&id=3252&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 3,\n\n');

insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('90','Chondrus crispus','f','f',null,'plant:bryophyte',null,'carrageen, Irish moss',null,null,'2769','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Tree&id=2769&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 3,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('5','Saccharomyces cerevisiae','t','f','unicellular_eukaryotic','eukaryote:fungi:saccharomyces','Yeast','yeast','11443547','17','4932','http://www.ncbi.nlm.nih.gov/htbin-post/Taxonomy/wgetorg?mode=Tree&id=4932&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 5,\n\nFull Taxonomy = Eukaryota; Fungi; Ascomycota; Saccharomycetes; Saccharomycetales; Saccharomycetaceae; Saccharomyces ,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('85','Ligula intestinalis','f','f',null,'animal:metazoa:flatworm',null,'tapeworm',null,null,'94845','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Tree&id=94845&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 1,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('86','Schistosoma mansoni','f','f',null,'animal:metazoa:flatworm',null,'blood fluke',null,null,'6183','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Tree&id=6183&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 1,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('87','Dugesia japonica','f','f',null,'animal:metazoa:flatworm',null,'planaria',null,null,'6161','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Tree&id=6161&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 1,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('88','Girardia tigrina','f','f',null,'animal:metazoa:flatworm','Dugesia tigrina','brown planaria',null,null,'6162','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Tree&id=6162&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 1,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('82','Macropus sp.','f','f',null,'animal:marsupial',null,'kangaroo',null,null,'9322','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Tree&id=9322&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 1,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('83','Macropus rufus','f','f',null,'animal:marsupial',null,'red kangaroo',null,null,'9321','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Tree&id=9321&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 1,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('84','Platypus sp. BF-2000','f','f',null,'animal:monotreme',null,'platypus, duck-billed platypus',null,null,'122837','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Tree&id=122837&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 1,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('78','Xenopus laevis','f','f',null,'animal:amphibian',null,'African clawed frog',null,null,'8355','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Tree&id=8355&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 1,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('79','Quercus alba','f','f',null,'plant:angiosperm:dicot',null,'white oak',null,null,'3513','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Tree&id=3513&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 7,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('80','Quercus palustris','f','f',null,'plant:angiosperm:dicot',null,'pin oak',null,null,'73152','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Tree&id=73152&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 7,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('81','Helianthus annuus','f','f',null,'plant:angiosperm:dicot',null,'common sunflower',null,null,'4232','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Tree&id=4232&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 7,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('75','Pinus radiata','f','f',null,'plant:gymnosperm:dicot',null,'Monterey pine',null,null,'3347','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Tree&id=3347&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 7,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('76','Pinus strobus','f','f',null,'plant:gymnosperm:dicot',null,'Eastern white pine',null,null,'3348','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Tree&id=3348&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 7,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('77','Felis catus','f','f',null,'animal:mammal','Felis domesticus','cat',null,null,'9685','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Tree&id=9685&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 1,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('71','Sorghum halepense','f','f',null,'plant:angiosperm:monocot:grass',null,'Johnson grass',null,null,'4560','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Tree&id=4560&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 7,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('72','Brassica napus','f','f',null,'plant:angiosperm:dicot:brassicaceae',null,'rapeseed',null,null,'3708','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Tree&id=4560&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 7,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('73','Brassica rapa','f','f',null,'plant:angiosperm:dicot:brassicaceae',null,'field mustard',null,null,'3711','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Tree&id=3711&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 7,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('74','Pinus taeda','f','f',null,'plant:gymnosperm:dicot',null,'loblolly pine',null,null,'3352','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Tree&id=3352&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 7,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('68','Hepatitis C virus','t','f',null,'virus',null,'',null,null,'11103','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Tree&id=11103&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = ?,\n\nFull Taxonomy = Viruses; ssRNA positive-strand viruses, no DNA stage; Flaviviridae; Hepacivirus ,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('69','Glycine max','f','f',null,'plant:angiosperm:dicot:legume',null,'soybean',null,null,'3847','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Tree&id=3847&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 7,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('70','Sorghum bicolor','f','f',null,'plant:angiosperm:monocot:grass',null,'sorghum',null,null,'4558','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Tree&id=4558&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 7,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('66','Solanum melongena','f','f',null,'plant:angiosperm:dicot',null,'eggplant, brinjal, aubergine',null,null,'4111','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Info&id=4111&lvl=3&keep=1&srchmode=2&unlock','Curation Tool Classification = 7,\n\nFull Taxonomy = Eukaryota; Viridiplantae; Embryophyta; Tracheophyta; Spermatophyta; Magnoliophyta; eudicotyledons; core eudicots; Asteridae; euasterids I; Solanales; Solanaceae; Solanum ,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('67','Zea mays ','t','f',null,'plant:angiosperm:monocot:grass:cereal',null,'maize, Indian corn, corn',null,null,'4577','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Tree&id=4577&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 7,\n\nFull Taxonomy = Eukaryota; Viridiplantae; Embryophyta; Tracheophyta; Spermatophyta; Magnoliophyta; Liliopsida; Poales; Poaceae; Zea ,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('43','Caenorhabditis elegans','f','f',null,'animal:metazoa:nematode',null,'worm',null,null,'6239','http://www.ncbi.nlm.nih.gov/htbin-post/Taxonomy/wgetorg?mode=Info&id=6239&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 1,\n\nFull Taxonomy = Eukaryota; Metazoa; Nematoda; Chromadorea; Rhabditida; Rhabditoidea; Rhabditidae; Peloderinae; Caenorhabditis ,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('63','Capsicum frutescens','f','f',null,'plant:angiosperm:dicot:solanaceae',null,'chili pepper, chile peppar',null,null,'4073','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Info&id=4073&lvl=3&keep=1&srchmode=2&unlock','Curation Tool Classification = 7,\n\nFull Taxonomy = Eukaryota; Viridiplantae; Embryophyta; Tracheophyta; Spermatophyta; Magnoliophyta; eudicotyledons; core eudicots; Asteridae; euasterids I; Solanales; Solanaceae; Capsicum,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('64','Lycopersicon esculentum','f','f',null,'plant:angiosperm:dicot:solanaceae',null,'tomatoes',null,null,'4081','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Info&id=4081&lvl=3&keep=1&srchmode=2&unlock','Curation Tool Classification = 7,\n\nFull Taxonomy = Eukaryota; Viridiplantae; Embryophyta; Tracheophyta; Spermatophyta; Magnoliophyta; eudicotyledons; core eudicots; Asteridae; euasterids I; Solanales; Solanaceae; Solanum; Lycopersicon ,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('65','Solanum tuberosum','f','f',null,'plant:angiosperm:dicot',null,'potatoes',null,null,'4113','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Info&id=4113&lvl=3&keep=1&srchmode=2&unlock','Curation Tool Classification = 7,\n\nFull Taxonomy = Eukaryota; Viridiplantae; Embryophyta; Tracheophyta; Spermatophyta; Magnoliophyta; eudicotyledons; core eudicots; Asteridae; euasterids I; Solanales; Solanaceae; Solanum ,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('61','Naegleria fowleri','f','f',null,'eukaryote',null,'amoeba',null,null,'5763','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Info&id=5763&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 4,\n\nFull Taxonomy = Eukaryota; Heterolobosea; Schizopyrenida; Vahlkampfiidae; Naegleria,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('62','Giardia intestinalis','f','f',null,'eukaryote','Giardia lamblia, Giardia duodenalis','',null,null,'5741','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Info&id=5741&lvl=3&keep=1&srchmode=2&unlock','Curation Tool Classification = 4,\n\nFull Taxonomy = Eukaryota; Diplomonadida; Hexamitidae; Giardiinae; Giardia ,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('58','Pteridium aquilinum','f','f',null,'plant:fern',null,'bracken',null,null,'32101','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Info&id=32101&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 3,\n\nFull Taxonomy = Eukaryota; Viridiplantae; Embryophyta; Tracheophyta; Filicophyta; Filicopsida; Filicales; Dennstaedtiaceae; Pteridium ,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('59','Deinococcus radiodurans','f','t',null,'prokaryote:archaebacteria',null,'Conan the Bacterium',null,null,'1299','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Info&id=1299&lvl=3&keep=1&srchmode=3&unlock','Curation Tool Classification = 2,\n\nFull Taxonomy = Bacteria; Thermus/Deinococcus group; Deinococcales; Deinococcus ,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('60','Synechocystis sp. PCC6803','f','t',null,'prokaryote:eubacteria',null,'cyanobacteria',null,null,'1148','http://www.ncbi.nlm.nih.gov:80/htbin-post/Taxonomy/wgetorg?mode=Info&id=1148&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 2,\n\nFull Taxonomy = Bacteria; Cyanobacteria; Chroococcales; Synechocystis,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('56','Glomus versiforme','f','f',null,'eukaryote:fungi',null,'arbuscular mycorrhizae',null,null,'43425','http://www.ncbi.nlm.nih.gov/htbin-post/Taxonomy/wgetorg?mode=Info&id=43425&lvl=3&srchmode=2&unlock','Curation Tool Classification = 5,\n\nFull Taxonomy = Eukaryota; Fungi; Zygomycota; Zygomycetes; Glomales; Glomaceae; Glomus ,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('57','Azolla caroliniana','f','f',null,'plant:fern',null,'mosquito fern',null,null,'39631','http://www.ncbi.nlm.nih.gov/htbin-post/Taxonomy/wgetorg?mode=Info&id=39631&lvl=3&srchmode=2&unlock','Curation Tool Classification = 3,\n\nFull Taxonomy = Eukaryota; Viridiplantae; Embryophyta; Tracheophyta; Filicophyta; Filicopsida; Hydropteridales; Azollaceae; Azolla ,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('53','Rattus norvegicus','f','f',null,'animal:mammal:rodentia',null,'rat',null,null,'10116','http://www.ncbi.nlm.nih.gov/htbin-post/Taxonomy/wgetorg?mode=Info&id=10116&lvl=3&keep=1&srchmode=2&unlock','Curation Tool Classification = 1,\n\nFull Taxonomy = Eukaryota; Metazoa; Chordata; Craniata; Vertebrata; Euteleostomi; Mammalia; Eutheria; Rodentia; Sciurognathi; Muridae; Murinae;     Rattus ,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('54','Trypanosoma cruzi','f','f',null,'eukaryote',null,'sleeping sickness parasite',null,null,'5693','http://www.ncbi.nlm.nih.gov/htbin-post/Taxonomy/wgetorg?mode=Undef&id=5693&lvl=0&keep=1&srchmode=2&unlock','Curation Tool Classification = 4,\n\nFull Taxonomy = Eukaryota; Euglenozoa; Kinetoplastida; Trypanosomatidae; Trypanosoma; Schizotrypanum ,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('55','Trypanosoma brucei','f','f',null,'eukaryote',null,'sleeping sickness parasite',null,null,'5691','http://www.ncbi.nlm.nih.gov/htbin-post/Taxonomy/wgetorg?mode=Undef&id=5691&lvl=0&keep=1&srchmode=2&unlock','Curation Tool Classification = 4,\n\nFull Taxonomy = Eukaryota; Euglenozoa; Kinetoplastida; Trypanosomatidae; Trypanosoma,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('51','Oryza sativa subsp. indica','t','f',null,'plant:angiosperm:monocot:grass:cereal',null,'Indian rice',null,null,'39946','http://www.ncbi.nlm.nih.gov/htbin-post/Taxonomy/wgetorg?mode=Tree&id=39946&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 7,\n\nFull Taxonomy = ,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('52','Oryza sativa  subsp. japonica','t','f',null,'plant:angiosperm:monocot:grass:cereal',null,'rice',null,null,'39947','http://www.ncbi.nlm.nih.gov/htbin-post/Taxonomy/wgetorg?mode=Tree&id=39947&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 7,\n\nFull Taxonomy = Eukaryota; Viridiplantae; Embryophyta; Tracheophyta; Spermatophyta; Magnoliophyta; Liliopsida; Poales; Poaceae; Oryza; Oryza,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('48','Schizosaccharomyces pombe','f','f',null,'eukaryote:fungi',null,'yeast, fission yeast, S. pombe',null,null,'4896','http://www.ncbi.nlm.nih.gov/htbin-post/Taxonomy/wgetorg?mode=Info&id=4896&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 5,\n\nFull Taxonomy = Eukaryota; Fungi; Ascomycota; Schizosaccharomycetales; Schizosaccharomycetaceae; Schizosaccharomyces ,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('49','Danio rerio','f','f',null,'animal:fish',null,'zebra fish, zebrafishes, zebra danio',null,null,'7955','http://www.ncbi.nlm.nih.gov/htbin-post/Taxonomy/wgetorg?mode=Info&id=7955&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 1,\n\nFull Taxonomy = Eukaryota; Metazoa; Chordata; Craniata; Vertebrata; Euteleostomi; Actinopterygii; Neopterygii; Teleostei; Euteleostei; Ostariophysi;     Cypriniformes; Cyprinidae; Rasborinae; Danio ,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('50','Homo sapiens','t','f',null,'animal:mammal:human',null,'human',null,null,'9606','http://www.ncbi.nlm.nih.gov/htbin-post/Taxonomy/wgetorg?mode=Tree&id=9606&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 1,\n\nFull Taxonomy = Eukaryota; Metazoa; Chordata; Craniata; Vertebrata; Euteleostomi; Mammalia; Eutheria; Primates; Catarrhini; Hominidae; Homo ,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('46','Mycoplasma pneumoniae','f','t',null,'prokaryote',null,'',null,null,'2104','http://www.ncbi.nlm.nih.gov/htbin-post/Taxonomy/wgetorg?mode=Info&id=2104&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 2,\n\nFull Taxonomy = Bacteria; Firmicutes; Bacillus/Clostridium group; Mollicutes; Mycoplasmataceae; Mycoplasma ,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('47','Pneumocystis carinii','f','f',null,'eukaryote:fungi',null,'',null,null,'4754','http://www.ncbi.nlm.nih.gov/htbin-post/Taxonomy/wgetorg?mode=Tree&id=4754&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 5,\n\nFull Taxonomy = Eukaryota; Fungi; Fungi incertae sedis; Pneumocystidaceae; Pneumocystis ,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('44','Drosophila melanogaster','f','f',null,'animal:insect',null,'fruit fly',null,null,'7227','http://www.ncbi.nlm.nih.gov/htbin-post/Taxonomy/wgetorg?mode=Undef&id=7227&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 1,\n\nFull Taxonomy = Eukaryota; Metazoa; Arthropoda; Tracheata; Hexapoda; Insecta; Pterygota; Neoptera; Endopterygota; Diptera; Brachycera; Muscomorpha; Ephydroidea; Drosophilidae; Drosophila ,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('45','Mycoplasma genitalium','f','t',null,'prokaryote',null,'',null,null,'2097','http://www.ncbi.nlm.nih.gov/htbin-post/Taxonomy/wgetorg?mode=Info&id=2097&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 2,\n\nFull Taxonomy = Bacteria; Firmicutes; Bacillus/Clostridium group; Mollicutes; Mycoplasmataceae; Mycoplasma ,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('41','Mus musculus','f','f',null,'animal:mammal:rodentia',null,'mouse',null,null,'10090','http://www.ncbi.nlm.nih.gov/htbin-post/Taxonomy/wgetorg?mode=Tree&id=10090&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 1,\n\nFull Taxonomy = Eukaryota; Metazoa; Chordata; Craniata; Vertebrata; Euteleostomi; Mammalia; Eutheria; Rodentia; Sciurognathi; Muridae; Murinae; Mus,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('42','Plasmodium falciparum','f','f',null,'eukaryote:apicomplexa',null,'malarial parasite P. falciparum',null,null,'5833','http://www.ncbi.nlm.nih.gov/htbin-post/Taxonomy/wgetorg?mode=Tree&id=5833&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 5,\n\nFull Taxonomy = Eukaryota; Alveolata; Apicomplexa; Haemosporida; Plasmodium ,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('39','Dictyostelium discoideum','f','f',null,'eukaryote:dictyosteliida',null,'slime mold',null,null,'44689','http://www.ncbi.nlm.nih.gov/htbin-post/Taxonomy/wgetorg?mode=Info&id=44689&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 5,\n\nFull Taxonomy = Eukaryota; Dictyosteliida; Dictyostelium,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('40','Takifugu rubripes rubripes','f','f',null,'animal:fish','Fugu rubripes','fugu, torafugu, puffer fish',null,null,'31033','http://www.ncbi.nlm.nih.gov/htbin-post/Taxonomy/wgetorg?mode=Tree&id=31033&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 1,\n\nFull Taxonomy = Eukaryota; Metazoa; Chordata; Craniata; Vertebrata; Euteleostomi; Actinopterygii; Neopterygii; Teleostei; Euteleostei; Neoteleostei; Acanthomorpha; Acanthopterygii; Percomorpha; Tetraodontiformes; Tetraodontidae; Takifugu; Takifugu rubripes ,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('38','Medicago truncatula','f','f',null,'plant:angiosperm:dicot:legume',null,'barrel medic',null,null,'3880','http://www.ncbi.nlm.nih.gov/htbin-post/Taxonomy/wgetorg?mode=Info&id=3880&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 7,\n\nFull Taxonomy = Eukaryota; Viridiplantae; Embryophyta; Tracheophyta; Spermatophyta; Magnoliophyta; eudicotyledons; core eudicots; Rosidae; eurosids I; Fabales; Fabaceae; Papilionoideae; Medicago ,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('6','Arabidopsis thaliana','t','f','multicellular_eukaryotic','plant:angiosperm:dicot:brassicaceae:arabidopsis','A. thaliana, Pilsella siliquasa','thale cress, mouse-eared cress','140000000','5','3702','http://www.ncbi.nlm.nih.gov/htbin-post/Taxonomy/wgetorg?mode=Info&id=3702&lvl=3&keep=1&srchmode=1&unlock, http://www.arabidopsis.org/aboutarabidopsis.html','Curation Tool Classification = 6,\n\nFull Taxonomy = Eukaryota; Viridiplantae; Embryophyta; Tracheophyta; Spermatophyta; Magnoliophyta; eudicotyledons; core eudicots; Rosidae; eurosids II; Brassicales; Brassicaceae; Arabidopsis,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('4','Escherichia coli','t','t','unicellular_eubacteria','prokaryote:eubacteria','E. coli','ecoli, E. coli','4639221','1','562','http://www.ncbi.nlm.nih.gov/htbin-post/Taxonomy/wgetorg?mode=Tree&id=562&lvl=3&keep=1&srchmode=1&unlock','Curation Tool Classification = 2,\n\nFull Taxonomy = Bacteria; Proteobacteria; gamma subdivision; Enterobacteriaceae; Escherichia ,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('107','test_speices','f','f','cell_structure','general_classification','Testorum scientificum','test','0','1','ncbi_taxonomy_acc','relevant_urls','Curation Tool Classification = 6,\n\nFull Taxonomy = full_taxonomy,\n\n');
--
insert into species (spc_pk, primary_scientific_name, is_sequenced_genome, is_circular_genome, cell_structure, general_classification, scientific_aliases, common_names, genome_size, num_chromosomes, ncbi_taxonomy_acc, relevant_urls, spc_ft_comments) values ('108','Pseudomonas aeruginosa','t','t','unicellular_eubacteria','prokaryote:eubacteria','P. aeruginosa','P. aeruginosa, pseudomonas','6200000','1','287','http://www.ncbi.nlm.nih.gov/htbin-post/Taxonomy/wgetorg?mode=Info&id=287&lvl=3&keep=1&srchmode=1&unlock Full Taxonomy = Bacteria; Proteobacteria; gamma subdivision; Pseudomonadaceae; Pseudomonas,\n\n',null);
--
----
---- PostgreSQL database dump
----
--
SET search_path = public, pg_catalog;
--
----
---- Data for TOC entry 1 (OID 33814)
---- Name: miame_type; Type: TABLE DATA; Schema: public; Owner: geoss
----
--
insert into  miame_type (miame_type_pk, miame_type_name) values (1,'Affymetrix');
insert into  miame_type (miame_type_pk, miame_type_name) values (2,'cDNA');
--
INSERT INTO study (sty_pk, study_name, sty_comments) values
(0,'default','Default value for unset studies'); 

INSERT INTO exp_condition (ec_pk, sty_fk, name) values (0,0,'default');
--
INSERT INTO disease (dis_name) values ('Acute Lymphoblastic Leukemia');
INSERT INTO disease (dis_name) values('Acute Myelogenous Leukemia');
INSERT INTO disease (dis_name) values('Adrenocortical Carcinoma');
INSERT INTO disease (dis_name) values('Alzheimers');
INSERT INTO disease (dis_name) values('Astrocytoma');
INSERT INTO disease (dis_name) values('Atypical Teratoid/Rhabdoid Tum');
INSERT INTO disease (dis_name) values('Bladder Carcinoma');
INSERT INTO disease (dis_name) values('Breast Carcinoma');
INSERT INTO disease (dis_name) values('Burkitt Lymphoma');
INSERT INTO disease (dis_name) values('Chronic Lymphocytic Leukemia');
INSERT INTO disease (dis_name) values('Colon Adenocarcinoma');
INSERT INTO disease (dis_name) values('Cutaneous Diffuse Large B-Cell');
INSERT INTO disease (dis_name) values('Cutaneous Follicular Lymphoma');
INSERT INTO disease (dis_name) values('Cystic Fibrosis');
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
INSERT INTO disease (dis_name) values('Primitive Neuroectodermal Tumor');
INSERT INTO disease (dis_name) values('Prostate Adenocarcinoma');
INSERT INTO disease (dis_name) values('Renal Cell Carcinoma');
INSERT INTO disease (dis_name) values('Rhabdomyosarcoma');
INSERT INTO disease (dis_name) values('Salivary Carcinoma');
INSERT INTO disease (dis_name) values('Small Cell Lung Cancer');
INSERT INTO disease (dis_name) values('Soft Tissue Sarcoma');
INSERT INTO disease (dis_name) values('Squamous Cell Lung Carcinoma');
INSERT INTO disease (dis_name) values('Stem Cell Research');
INSERT INTO disease (dis_name) values('T-Cell Acute Lymphoblastic Leukemia');
INSERT INTO disease (dis_name) values('Thyroid Carcinoma');



INSERT INTO arraylayout (al_pk, con_fk, name, technology_type,
chip_cost) values (100, (select con_pk from contact where
contact_fname='admin'), 'Not Listed', 'Unknown', 0);
