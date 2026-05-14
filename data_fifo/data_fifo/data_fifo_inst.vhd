	component data_fifo is
		port (
			data    : in  std_logic_vector(31 downto 0) := (others => 'X'); -- datain
			wrreq   : in  std_logic                     := 'X';             -- wrreq
			rdreq   : in  std_logic                     := 'X';             -- rdreq
			wrclk   : in  std_logic                     := 'X';             -- wrclk
			rdclk   : in  std_logic                     := 'X';             -- rdclk
			aclr    : in  std_logic                     := 'X';             -- aclr
			q       : out std_logic_vector(31 downto 0);                    -- dataout
			rdusedw : out std_logic_vector(10 downto 0);                    -- rdusedw
			wrusedw : out std_logic_vector(10 downto 0);                    -- wrusedw
			rdempty : out std_logic;                                        -- rdempty
			wrfull  : out std_logic                                         -- wrfull
		);
	end component data_fifo;

	u0 : component data_fifo
		port map (
			data    => CONNECTED_TO_data,    --  fifo_input.datain
			wrreq   => CONNECTED_TO_wrreq,   --            .wrreq
			rdreq   => CONNECTED_TO_rdreq,   --            .rdreq
			wrclk   => CONNECTED_TO_wrclk,   --            .wrclk
			rdclk   => CONNECTED_TO_rdclk,   --            .rdclk
			aclr    => CONNECTED_TO_aclr,    --            .aclr
			q       => CONNECTED_TO_q,       -- fifo_output.dataout
			rdusedw => CONNECTED_TO_rdusedw, --            .rdusedw
			wrusedw => CONNECTED_TO_wrusedw, --            .wrusedw
			rdempty => CONNECTED_TO_rdempty, --            .rdempty
			wrfull  => CONNECTED_TO_wrfull   --            .wrfull
		);

