library IEEE;							--voir datasheet MICRON MT9M413
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
library UNISIM;
use UNISIM.VComponents.all;


entity Gestion_Capteur is
Port( --Entrées:
	  	reset                : in std_logic;
      clk_capteur          : in std_logic;
		clk120M              : in std_logic;
		call_done            : in std_logic;
		row_done             : in std_logic;
		pix_clk              : in std_logic;
		donnees_capteur	   : in std_logic_vector(99 downto 0);
  		donnees_capteur_temp	: out std_logic_vector(99 downto 0);
		--Sorties:
		flag_lancement       : in std_logic;
		flag_fin_image       : out std_logic;
		flag_fin_ligne       : out std_logic;
		flag_init_capt       : out std_logic;
		Capteur_ready        : out std_logic;
		Fin_im               : out std_logic;
		compH_out            : in std_logic_vector(10 downto 0);
		compt_clk_temp       : out std_logic_vector(7 downto 0) ;
		Compteur_images_load : in std_logic_vector(15 downto 0) ;
		Compteur_images_out  : out std_logic_vector(15 downto 0) ;
		flag_visu            : in std_logic;
		coord_y              : in std_logic_vector(15 downto 0) ;
		coord_y_fin          : in std_logic_vector(15 downto 0) ;
  		expo                 : in std_logic_vector(10 downto 0);
		row_addr             : out std_logic_vector(9 downto 0);
      row_strt             : out std_logic;
      ld_shift             : out std_logic;
      data_read_en         : out std_logic;
		pg_n                 : out std_logic;
		tx_n                 : out std_logic;
		dark                 : out std_logic;
		standby              : out std_logic;
		sysclk	            : out std_logic;
		lrst                 : out std_logic;
		cal_strt             : out std_logic);
end Gestion_Capteur;

architecture Arch of Gestion_Capteur is

component compteur 
port( i1clk,i1reset  : in std_logic;
		o8comt_clk     : out std_logic_vector(7 downto 0);
		o11compt_ligne : out std_logic_vector(10 downto 0));
end component;


--Declaration des états de la machine d'état.
type state_type is (Cal_0,Cal_1,s1,s2,s3,s4,s5,s6,s7,s8,s9,s10);
signal state: state_type;

type state_init_type is (init_1,init_2,init_3,visu_1);
signal state_init: state_init_type;

signal compt_clk   : std_logic_vector(7 downto 0);
signal compt_ligne : std_logic_vector(10 downto 0);
signal debut_capt  : std_logic_vector(10 downto 0);
signal debut_expo  : std_logic_vector(10 downto 0);
signal fin_capt    : std_logic_vector(10 downto 0);

signal flag_fin_ligne_temp : std_logic;
signal debut_image         : std_logic;
signal flag_init           : std_logic;
signal Fin_im_temp         : std_logic;
signal flag_fin_im_temp    : std_logic;

signal donnees             : std_logic_vector(99 downto 0);
signal Compteur_images     : std_logic_vector(15 downto 0);
signal Compt_Visu          : std_logic_vector(24 downto 0);
signal Compteur_seq_charge : std_logic;


begin


debut_capt <= coord_y(10 downto 0);
debut_expo <= expo;
fin_capt   <= coord_y_fin(10 downto 0);


--Description des cycles de la machine de gestion des signaux de synchronisation.

process(clk_capteur,reset)
begin
	if(reset='0') then 
		lrst <= '1';
		row_addr <= debut_capt(9 downto 0);
		row_strt <= '1';
		ld_shift <= '0';
		data_read_en <= '0';
		pg_n <= '1';
		tx_n <= '1';
		flag_fin_ligne_temp<='1';
		Capteur_ready<='0';
		Compteur_images <= (others => '0');
		Fin_im_temp <='0';
		flag_fin_im_temp<='0';
		compt_clk <= "00000000";
		compt_ligne <= debut_capt;
		state <= Cal_0;
		Compteur_seq_charge <= '0';
		donnees<=(others=>'0');
	elsif(rising_edge(clk_capteur))then	
		case state is
				--Lancement du calibrage auto des conv A/N du reg ADC
				--Etat jusqu'au 3éme coup de clk.
			when Cal_0 => 	if(compt_clk >= 7 ) then state <= Cal_1;
								else state <= Cal_0;				
								end if;		
								lrst         <= '0';
								row_addr     <= debut_capt(9 downto 0);
								row_strt     <= '1';
							   ld_shift     <= '0';
							   data_read_en <= '0';
							   pg_n         <= '1';
							   tx_n         <= '1';
								compt_clk    <= compt_clk + '1';
																					 		
				--Le calibrage auto des conv A/N du reg ADC dur 112 coups de CLK
				--Etat jusqu'au 120éme coup de clk (115+5 pour etre sure).
			when Cal_1 => 	if(call_done='0') then
									state <= s1;
									compt_clk<="00000000";
								else
									state <= Cal_1;
									compt_clk <= compt_clk + '1';
								end if;
								lrst         <= '1';
								row_addr     <= debut_capt(9 downto 0);
								row_strt     <= '1'; 
						      ld_shift     <= '0';
						      data_read_en <= '0';
						      pg_n         <= '1';
						      tx_n         <= '1';

			when s1 =>		state            <= s2;
								flag_fin_im_temp <='0';	
								lrst             <= '1';
								row_addr         <= compt_ligne(9 downto 0);
								row_strt         <= '1';
						      ld_shift         <= '0';
						      data_read_en     <= '0';
						      pg_n             <= '1';
						      tx_n             <= '1';
								compt_clk        <= compt_clk + 1;

		  	when s2 =>		if(compt_clk>=5) then state <= s3;
								else state <= s2;
								end if;
								if(flag_init='1') then
									Compteur_images     <= Compteur_images_load ;
									Compteur_seq_charge <= '1';
								else
									Compteur_seq_charge <= '0';
								end if;
								lrst         <= '1';
								row_addr     <= compt_ligne(9 downto 0);
								row_strt     <= '1';
						      ld_shift     <= '0';
						      data_read_en <= '0';
						      pg_n         <= '1';
						      tx_n         <= '1';
								compt_clk    <= compt_clk + 1;
								Fin_im_temp  <='0';

				--Etat entre le 2éme et le 4éme coups de clk.
			when s3 =>		if(compt_clk>=7) then state <= s4;
								else state <= s3;
								end if;
								flag_fin_ligne_temp <= '0';
								lrst                <= '1';
								row_addr            <= compt_ligne(9 downto 0);
								row_strt            <= '0';
						      ld_shift            <= '0';
						      data_read_en        <= '0';
						      pg_n                <= '1';
						      tx_n                <= '1';
								compt_clk           <= compt_clk + 1;
			
				--Etat entre le 4éme et le 66éme coups de clk.	
			when s4 =>		if(compt_clk>=69) then 
									if(compt_ligne=debut_expo)then
										state <= s5;				
									elsif(compt_ligne>=fin_capt) then
										state <= s6;				
									else
										state <= s7;				
									end if;
								end if;
								lrst         <= '1';
								row_strt     <= '1';
						      ld_shift     <= '0';
						      data_read_en <= '0';
						      pg_n         <= '1';
						      tx_n         <= '1';
								compt_clk    <= compt_clk + 1;
				--Etat entre le 66éme et le 130éme coups de clk.
				--Cas pour la ligne 304.
			when s5 =>		if(compt_clk>=133) then 
									if(compt_ligne>=debut_expo) then
										state <= s8;
									else
										state <= s9;			
									end if;
								end if;
								lrst         <= '1';
								row_strt     <= '1';
						      ld_shift     <= '0';
						      data_read_en <= '0';
						      pg_n         <= '0';
						      tx_n         <= '1';
						   	compt_clk    <= compt_clk + 1; 																
				--Etat entre le 66éme et le 130éme coups de clk.
				--Cas pour la ligne 312.
			when s6 =>		if(compt_clk>=133) then 
									if(compt_ligne>=debut_expo) then
										state <= s8;			
									else
										state <= s9;			
									end if;
								end if;
								lrst         <= '1';
								row_strt     <= '1';
						      ld_shift     <= '0';
						      data_read_en <= '0';
						      pg_n         <= '1';
						      tx_n         <= '0';
						    	compt_clk    <= compt_clk + 1;
				--Etat entre le 66éme et le 130éme coups de clk.
				--Cas pour les autres lignes.
			when s7 =>		if(compt_clk>=133) then 
								   if(compt_ligne>=debut_expo) then
										state <= s8;			
									else
										state <= s9;				
									end if;
	 							end if;
								lrst         <= '1';
								row_strt     <= '1';
						      ld_shift     <= '0';
						      data_read_en <= '0';
						      pg_n         <= '1';
						      tx_n         <= '1';
						   	compt_clk    <= compt_clk + 1;
				--Etat entre le 130éme et le 131éme coups de clk.
				--Cas pour la 700éme ligne  et celles situées aprés
			when s8 => 		if(compt_clk>=134) then 
									state <= s10;
								else
									state <= s8;
								end if;
								lrst                <= '1';
								row_strt            <= '1';
						      ld_shift            <= '0';
						      data_read_en        <= '0';
								flag_fin_ligne_temp <='1';
								pg_n                <= '1';
						      tx_n                <= '1';
								compt_clk           <= compt_clk + 1;
				--Etat entre le 130éme et le 131éme coups de clk.
				--Cas pour les lignes avant 700.
			when s9 => 		if(compt_clk>=134) then
									state <= s10;
								else
									state <= s9;
								end if;
								lrst                <= '1';
								row_strt            <= '1';
						      ld_shift            <= '0';
						      data_read_en        <= '0';
						      pg_n                <= '0';
						      flag_fin_ligne_temp <='1';
								tx_n                <= '1';
								compt_clk           <= compt_clk + 1;
				--Dernier état de la ligne, dur 1 coup de clk.
			when s10 =>		if(compt_clk>=135) then 
									state <= s1;
									if(compt_ligne<fin_capt)then 
										compt_ligne <= compt_ligne + 1;
									else
										compt_ligne <=debut_capt;
										if(Compteur_images=0) then
											Compteur_images<=(others=>'0');
										else
											Compteur_images <= Compteur_images -1;
										end if;
										flag_fin_im_temp <= '1';
										Fin_im_temp      <= '1';
										Capteur_ready    <= '1';
									end if;
								else
									state <= s10;								
								end if;
								lrst         <= '1';
								row_strt     <= '1';
						      ld_shift     <= '1';
						      data_read_en <= '1';
						      pg_n         <= '1';								  
						      tx_n         <= '1';
								compt_clk    <= "00000000";
								donnees      <=not donnees;
			
		end case;
	end if;
end process;


--process pour la visualisation ou traitement 

process( clk120M,reset )					 
begin
	if(reset='0') then 
		flag_init  <='0';
		state_init <=init_1;
	elsif(rising_edge(clk120M))then
		case state_init is
			when init_1 => 	if(flag_lancement='0') then
										state_init <= init_2;
									else
										state_init <= init_1;										
	 								end if;
									flag_init  <= '0';
									Compt_Visu <= "0000000000000000000000001"; -- laisse un tps de traitement entre 2 images

		 	when init_2 => 	if(Fin_im_temp='1')then
										state_init <= init_3;
										flag_init  <= '1';
									else
										state_init <=init_2;									
	 									flag_init  <='0';
									end if;
									Compt_Visu <= "0000000000000000000000001";

			when init_3 => 	if(Compteur_seq_charge='1')then
										if(flag_visu='0') then
											state_init <= init_1;
										else
											state_init <= visu_1;
										end if;										
									else
										state_init <= init_3;																			
	 								end if;
									flag_init  <= '1';
									Compt_Visu <= "0000000000000000000000001";
			
			when visu_1 => 	if(Compt_Visu="0000000000000000000000000") then
										state_init <= init_1;
									else
										state_init <= visu_1;
									end if;
									flag_init  <= '0';
									Compt_Visu <= Compt_Visu +1;
		end case;
	end if;
end process;

Fin_im         <= Fin_im_temp;
flag_fin_image <= flag_fin_im_temp;--flag_init;
debut_image    <= '0' when (flag_lancement='0' or flag_fin_ligne_temp='1') else '1';
flag_fin_ligne <= flag_fin_ligne_temp;

--signaux fixes
dark                 <= '1';
standby              <= '1';
cal_strt             <= '1';
sysclk               <= clk_capteur;
Compteur_images_out  <=  Compteur_images;					
flag_init_capt       <= flag_init;
compt_clk_temp       <= compt_clk;
donnees_capteur_temp <= donnees_capteur when call_done='1' else donnees; 

end Arch;