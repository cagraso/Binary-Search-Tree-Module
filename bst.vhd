
-- Binary Search Tree (BST) Module --
------------------------------------------------------------------------------------------------------------------------------
-- Brief explanation of the module:

-- Binary Search Tree module can store and iterate over a BST having a user defined maximum node number. 
-- Module iterates over a binary search tree at every clock cycle. 
-- Each node in the tree is assigned to a specific index number. To access a node in the tree, assigned index values are used.
-- Node values are stored in an indexed array.
-- Child info of each node is stored in 2D array which holds index numbers of each child.
-- Index values are stored in array to determine used and available indices.

-- Module functional summary:
    -- Constructing tree with input node data.
    -- Iterating over the tree.
    -- Inserting a new node.
    -- Deleting a node.
    -- Finding a node.
    -- Sending results. 
------------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity bst is
    generic (   DATA_WIDTH  :   integer range 0 to 511:=20; -- data width of the tree data including node value, left child node index and right child node index
                TREE_SIZE   :   integer range 0 to 511:=64; -- maximum number of nodes in the tree
                VALUE_WIDTH :   integer range 0 to 8:=8;    -- node value data vector width
                IND_WIDTH   :   integer range 0 to 9:=6     -- node index data vector width
            );
    Port    (   DATA        :   in std_logic_vector(DATA_WIDTH-1 downto 0); -- tree data including node value, left child node index and right child node index
                CLK         :   in std_logic;                               -- module clock signal
                RST         :   in std_logic;                               -- module reset signal
                TREE_IN     :   in std_logic;                               -- tree data ready signal
                INSERT      :   in std_logic;                               -- insert a new node signal
                FIND        :   in std_logic;                               -- find a node start signal
                FIND_IND    :   out std_logic_vector(IND_WIDTH-1 downto 0); -- index of the found tree node
                FOUND       :   out std_logic;                              -- node found indicator
                NOT_FOUND   :   out std_logic;                              -- node doesn't exist/not found indicator
                DELETE      :   in std_logic                                -- delete a tree node 
            );
end bst;

architecture behavioral of bst is

-- Node value array that assigns a specific index for each node
-- ( tree indices: 1 to TREE_SIZE, node values: 1 to 2**VALUE_WIDTH - 1 ) (index 0 and value 0 is not used) 
type node_value_array is array (0 to TREE_SIZE) of integer range 0 to (2**VALUE_WIDTH - 1);
signal tree_nodes: node_value_array; -- tree nodes value array 

-- Child info array that holds child indices of a node
-- ( tree indices: 1 to TREE_SIZE, child type: 0-left child, 1-right child, node indices: 1 to TREE_SIZE ) (index 0 is not used)
type node_child_array is array (0 to TREE_SIZE, 0 to 1) of integer range 0 to TREE_SIZE; 
signal node_child: node_child_array; -- child index 2D array of the tree 


-- Command signals
signal initialize_tree: std_logic:='0';
signal construct_tree:  std_logic:='0';
signal insert_cmd:      std_logic:='0';
signal find_cmd:        std_logic:='0';
signal delete_cmd:      std_logic:='0';

-- Command / Data retrieve registers
signal in_node_val:     integer range 0 to (2**VALUE_WIDTH - 1); 
signal in_child_l_ind:  integer range 0 to TREE_SIZE; 
signal in_child_r_ind:  integer range 0 to TREE_SIZE; 
signal insert_val:      integer range 0 to (2**VALUE_WIDTH - 1);
signal find_val:        integer range 0 to (2**VALUE_WIDTH - 1);
signal delete_val:      integer range 0 to (2**VALUE_WIDTH - 1);

-- Binary search tree controller signals / registers
signal cnt_state :      std_logic_vector(1 downto 0):="00"; 
signal insert_node:     std_logic:='0';
signal delete_en:       std_logic:='0';
signal delete_type_1:   std_logic:='0';
signal delete_type_2:   std_logic:='0';
signal delete_type_3:   std_logic:='0';
signal delete_type_4:   std_logic:='0';
signal delete_type_5:   std_logic:='0';
signal del_ready_1:     std_logic:='0';
signal del_ready_2:     std_logic:='0';
signal del_ready_3:     std_logic:='0';
signal del_ready_4:     std_logic:='0';
signal del_ready_5:     std_logic:='0';
signal node_val:        integer range 0 to (2**VALUE_WIDTH - 1);
signal itr_tree_en:     std_logic:='0';

-- Tree iteration signals
signal node_reached:    std_logic:='0';
signal node_ind:        integer range 0 to TREE_SIZE;
signal leaf_reached:    std_logic:='0';
signal leaf_ind:        integer range 0 to TREE_SIZE;
signal itr_ind:         integer range 0 to TREE_SIZE;
signal current_ind:     integer range 0 to TREE_SIZE;
signal root_ind:        integer range 0 to TREE_SIZE;
signal parent_ind:      integer range 0 to TREE_SIZE;
signal insert_ind:      integer range 0 to TREE_SIZE;
signal insert_loc:      std_logic:='0';
signal insert_pst:      std_logic:='0';
signal root_hit:        std_logic:='0';
signal insert_reg:      std_logic:='0';
signal root_check:      std_logic:='0';

-- Delete tree node process signals
signal del_state:       std_logic:='0';
signal child_status:    std_logic_vector(1 downto 0):="00";
signal parent_l_r:      std_logic:='0';
signal inorder_pred_en: std_logic:='0';
signal right_child_ind: integer range 0 to TREE_SIZE;

-- Finding inorder predecessor signals
signal first_itr:       std_logic:='0';
signal pred_parent_ind: integer range 0 to TREE_SIZE;
signal pred_ind:        integer range 0 to TREE_SIZE;
signal inord_ind:       integer range 0 to TREE_SIZE;

-- Index array that stores available and used indices for tree nodes
type node_index_array is array (0 to TREE_SIZE-1) of integer range 0 to TREE_SIZE; 
signal ind_array:       node_index_array; -- index array that holds available index values for the tree nodes
signal ind_array_size:  integer range 0 to TREE_SIZE; -- size of the index array      

begin

-- Receive command / Register data -- 
-- This process stores input node value and left/right child node index values when it receives TREE_IN signal. 
-- New node inserting process is started when INSERT signal is received. 
-- Process triggers tree search for a requested node when it receives FIND signal.
-- Deleting a tree node process is started when DELETE signal is received.  
command_data_retrieve: process(CLK)
begin

    if rising_edge (CLK) then
     
        if (RST = '1') then
        
            initialize_tree <= '1';         -- initialize arrays with zero values representing non-usage
            construct_tree  <= '0';
            insert_cmd      <= '0';
            find_cmd        <= '0'; 
            delete_cmd      <= '0';
               
        else
        
            initialize_tree <= '0';
       
            -- Tree node value and child indices data for constructing the tree 
            if (TREE_IN = '1') then
                in_node_val     <= to_integer(unsigned( DATA(VALUE_WIDTH - 1 downto 0) )); 
                in_child_l_ind  <= to_integer(unsigned( DATA(IND_WIDTH + VALUE_WIDTH - 1 downto VALUE_WIDTH) )); 
                in_child_r_ind  <= to_integer(unsigned( DATA(DATA_WIDTH - 1 downto IND_WIDTH + VALUE_WIDTH) ));    
              
                construct_tree  <= '1';     -- construct tree command
            else
                construct_tree  <= '0';
            end if;
            
            -- Inserting a new node to the tree
            if (INSERT = '1') then
                insert_val      <= to_integer(unsigned( DATA(VALUE_WIDTH - 1 downto 0) ));    
              
                insert_cmd      <= '1';     -- insert a node command
            else
                insert_cmd      <= '0';
            end if;
            
            -- Finding a node in the tree
            if (FIND = '1') then
                find_val        <= to_integer(unsigned( DATA(VALUE_WIDTH - 1 downto 0) ));    
              
                find_cmd        <= '1';     -- find a node command
            else
                find_cmd        <= '0';
            end if;
            
            -- Deleting a node from the tree
            if (DELETE = '1') then
                delete_val      <= to_integer(unsigned( DATA(VALUE_WIDTH - 1 downto 0) ));    
              
                delete_cmd      <= '1';     -- delete a node commmand
            else
                delete_cmd      <= '0';
            end if;

        end if;  
    end if;
end process command_data_retrieve;


-- Control of the tree operation processes --
-- This process controls tree iteration, node search, node insert and node delete processes;
-- Finding a tree node:
-- 1- enable "iterate_tree process" 
-- 2- check for "node_reached" signal 
-- 3- get node index

-- Inserting a new node to the tree:
-- 1- enable "iterate_tree process" 
-- 2- check for "leaf_reached" signal 
-- 3- get leaf index 

-- Deleting a tree node:
-- 1- enable "iterate_tree process" 
-- 2- check for "node_reached" signal 
-- 3- get node index 
-- 4- check for child status
-- 5- replace or delete the node
bst_controller: process(CLK)
begin

    if rising_edge (CLK) then
    
        if (RST = '1') then
        
            cnt_state       <= "00";    -- controller state
            itr_tree_en     <= '0';     -- iterate tree enable signal
            insert_node     <= '0';     -- insert a node command
            FOUND           <= '0';     -- node found indicator
            NOT_FOUND       <= '0';     -- node not found indicator
            delete_en       <= '0';     -- delete node enable signal
            delete_type_1   <= '0';     -- delete type indicator (defines child status)
            delete_type_2   <= '0';     -- delete type indicator (defines child status)
            delete_type_3   <= '0';     -- delete type indicator (defines child status)
            delete_type_4   <= '0';     -- delete type indicator (defines child status)
            delete_type_5   <= '0';     -- delete type indicator (defines child status)
            
        else
        
            -- Cases for insert, delete and find commands
            case(cnt_state) is
            
                when "00" => -- Wait for a command 
                    
                    if ( (insert_cmd or find_cmd or delete_cmd) = '1' ) then
                    
                        -- Insert a node command
                        if (insert_cmd = '1') then
                            cnt_state <= "01";
                        end if;
                        
                        -- Find a node command
                        if (find_cmd = '1') then
                            cnt_state <= "10";
                        end if;
                        
                        -- Delete a node command
                        if (delete_cmd = '1') then
                            cnt_state <= "11";
                        end if;
                        
                    else
                        cnt_state <= "00";
                    end if;
                    
                    itr_tree_en     <= '0';
                    insert_node     <= '0';
                    FOUND           <= '0';
                    NOT_FOUND       <= '0';
                    delete_en       <= '0';
                    delete_type_1   <= '0';
                    delete_type_2   <= '0';
                    delete_type_3   <= '0';
                    delete_type_4   <= '0';
                    delete_type_5   <= '0';

                when "01" => -- Insert
                    
                    node_val    <= insert_val;
                    itr_tree_en <= '1';
            
                    if (leaf_reached = '1') then
                        insert_node  <= '1';
                        cnt_state    <= "00";
                    else
                        insert_node  <= '0';
                        cnt_state    <= "01";
                    end if;
                    
                    FOUND           <= '0';
                    NOT_FOUND       <= '0';
                    delete_en       <= '0';
                    delete_type_1   <= '0';
                    delete_type_2   <= '0';
                    delete_type_3   <= '0';
                    delete_type_4   <= '0';
                    delete_type_5   <= '0';
                    
                when "10" => -- Find
                    
                    node_val    <= find_val;
                    itr_tree_en <= '1';
                    
                    -- Checking if the node is found
                    if (node_reached = '1') then
                        FIND_IND        <= std_logic_vector(to_unsigned(node_ind,IND_WIDTH));
                        FOUND           <= '1';
                    else
                        FOUND           <= '0';
                    end if;    
            
                    -- Checking if a leaf is reached
                    if (leaf_reached = '1') then
                        NOT_FOUND       <= '1';
                    else
                        NOT_FOUND       <= '0';
                    end if; 
                    
                    -- Checking for the end of operation
                    if ( (node_reached = '1') or (leaf_reached = '1') ) then
                        cnt_state       <= "00";
                    else
                        cnt_state       <= "10";
                    end if; 
                    
                    insert_node     <= '0';
                    delete_en       <= '0';
                    delete_type_1   <= '0';
                    delete_type_2   <= '0';
                    delete_type_3   <= '0';
                    delete_type_4   <= '0';
                    delete_type_5   <= '0';
                    
                when "11" => -- Delete
                    
                    node_val    <= delete_val;
                    itr_tree_en <= '1';
                    delete_en   <= '1';
                    
                    -- Delete types which defines child status info of a node 
                    if (del_ready_1 = '1') then
                        delete_type_1   <= '1';
                    else    
                        delete_type_1   <= '0';
                    end if; 
                    
                    if (del_ready_2 = '1') then
                        delete_type_2   <= '1';
                    else    
                        delete_type_2   <= '0';
                    end if;
                    
                    if (del_ready_3 = '1') then
                        delete_type_3   <= '1';
                    else    
                        delete_type_3   <= '0';
                    end if;
                    
                    if (del_ready_4 = '1') then
                        delete_type_4   <= '1';
                    else    
                        delete_type_4   <= '0';
                    end if;
                    
                    if (del_ready_5 = '1') then
                        delete_type_5   <= '1';
                    else    
                        delete_type_5   <= '0';
                    end if;
                    
                    -- Checking for the end of operation
                    if ((del_ready_1 = '1')or(del_ready_2 = '1')or(del_ready_3 = '1')or(del_ready_4 = '1')or(del_ready_5 = '1')) then
                        cnt_state       <= "00";
                    else
                        cnt_state       <= "11";
                    end if;
                    
                    insert_node     <= '0';
                    FOUND           <= '0';
                    NOT_FOUND       <= '0';
                    
                when others => null;
            end case;
        
        end if; 
    end if; 
end process bst_controller;


-- Iterating over the binary tree for search, delete and insert operations --
iterate_tree: process(CLK)
begin

    if rising_edge (CLK) then
    
        if (itr_tree_en = '1') then
        
            -- Finding left/right position for the next iteration  
            if (node_val < tree_nodes(itr_ind)) then 
                itr_ind         <= node_child(itr_ind,0);   -- get index of left child
                current_ind     <= itr_ind;
                insert_loc      <= '0';                     -- insert as a left child of current node if node is a leaf
                node_reached    <= '0';
            elsif (node_val = tree_nodes(itr_ind)) then 
                node_reached    <= '1';
                node_ind        <= itr_ind;
                parent_ind      <= current_ind;
            else
                itr_ind         <= node_child(itr_ind,1);   -- get index of right child
                current_ind     <= itr_ind;
                insert_loc      <= '1';                     -- insert as a right child of current node if node is a leaf
                node_reached    <= '0';
            end if;
            
            -- Checking if a leaf is reached 
            if (itr_ind = 0) then
                leaf_reached <= '1';
            else
                leaf_reached <= '0';
            end if;
            
            -- Registering insert element index info 
            if ( ( itr_ind = 0 ) and ( insert_reg = '1') ) then
                insert_ind   <= current_ind;                -- parent index of new element
                insert_pst   <= insert_loc;
                insert_reg   <= '0';
            end if;
            
            -- Checking if search node is root
            if (root_check = '1') then
                if (node_val = tree_nodes(itr_ind)) then 
                    root_hit    <= '1';
                else
                    root_hit    <= '0';
                end if;
            end if;
            
            root_check      <= '0';
            
        else
        
            itr_ind         <= root_ind;
            root_check      <= '1';
            current_ind     <= 0;
            insert_loc      <= '0';
            parent_ind      <= 0;
            root_hit        <= '0';
            insert_reg      <= '1';
            node_reached    <= '0';
            leaf_reached    <= '0';
            
        end if;
    
    end if;   
end process iterate_tree;


-- Deleting a tree node --
-- This process controls deleting a node from the tree;
-- 1- check for "node_reached/leaf_reached" signal 
-- 2- get node/leaf index 
-- 3- check for child status:
--      - Case1: Leaf 
--      - Case2: Node with single child
--      - Case3: Node with left and right child
-- 4- process corresponding to child status cases:
--      - Case1: Delete the node
--      - Case2: Replace the node with its child, delete the node
--      - Case3: Find inorder predecessor (a leaf) and replace the node with its predecessor, delete the node
delete_tree_node:process(CLK)
begin

    if rising_edge(CLK) then
        
        if (delete_en = '1') then
        
            case(del_state) is
            
                when '0' =>
                
                    -- Checking if the node is reached
                    if (node_reached = '1') then
                        del_state   <= '1';
                    else
                        del_state   <= '0'; 
                    end if;
                    
                    -- Determining child status of the node
                    if ( node_child(node_ind,0) = 0 ) then
                        child_status(1) <= '0';
                    else
                        child_status(1) <= '1';
                    end if;
                    
                    if ( node_child(node_ind,1) = 0 ) then
                        child_status(0) <= '0';
                    else
                        child_status(0) <= '1';
                    end if;
                    
                    -- Determining the node connection with it's parent
                    if ( node_child(parent_ind,0) = node_ind ) then
                        parent_l_r <= '0'; -- node is left child of it's parent
                    else
                        parent_l_r <= '1'; -- node is right child of it's parent
                    end if;
                    
                    del_ready_1     <= '0';
                    del_ready_2     <= '0';
                    del_ready_3     <= '0';
                    inorder_pred_en <= '0';
                    
                when '1' =>
                
                    -- Determining delete types corresponding to child status
                    if ( child_status = "00" ) then     -- node is a leaf
                    
                        del_ready_1     <= '1';
                        inorder_pred_en <= '0';
                         
                    elsif ( child_status = "01" ) then  -- node has only right child
                    
                        del_ready_2     <= '1';
                        inorder_pred_en <= '0';
                        
                    elsif ( child_status = "10" ) then  -- node has only left child
                    
                        del_ready_3     <= '1';
                        inorder_pred_en <= '0';
                    
                    else -- child_status = "11"         -- node has left child and right child
                         
                        right_child_ind     <= node_child(node_ind,1);
                        inorder_pred_en     <= '1';     -- assert find inorder predecessor enable signal
                        
                        del_ready_1         <= '0';
                        del_ready_2         <= '0';
                        del_ready_3         <= '0';

                    end if;
                    
                    del_state   <= '1';
                    
                when others => null;         
            end case;
        
        else
            del_state       <= '0';
            del_ready_1     <= '0';
            del_ready_2     <= '0';
            del_ready_3     <= '0';
            inorder_pred_en <= '0';
        
        end if;
    
    end if;
end process delete_tree_node;


-- Finding inorder predecessor of a node --
-- This process finds inorder predecessor of a node to be used in node delete process.
inorder_predecessor: process(CLK)
begin

    if rising_edge (CLK) then
    
        if (inorder_pred_en = '1') then
          
            if(first_itr = '0') then        -- check for the first iteration
            
                if ( node_child(right_child_ind,0) = 0 ) then           -- check if left child not exists 
                
                    del_ready_4     <= '1';
                    pred_ind        <= right_child_ind;
                    first_itr       <= '0';
                    del_ready_5     <= '0';
                
                else
                    pred_parent_ind <= inord_ind;
                    inord_ind       <= node_child(right_child_ind,0);   -- go to the left child
                    first_itr       <= '1';
                    del_ready_4     <= '0';
                    del_ready_5     <= '0';
                    
                end if;      
 
            else
                if ( node_child(inord_ind,0) = 0 ) then                 -- check if left child not exists
                
                    del_ready_5     <= '1';
                    pred_ind        <= inord_ind;
                    first_itr       <= '1';
                    del_ready_4     <= '0';
                
                else
                    pred_parent_ind <= inord_ind;
                    inord_ind       <= node_child(inord_ind,0);         -- go to the left child
                    first_itr       <= '1';
                    del_ready_5     <= '0';
                    del_ready_4     <= '0';
                    
                end if;        
                
            end if;
   
        else
            del_ready_4     <= '0';
            del_ready_5     <= '0';
            first_itr       <= '0';
        
        end if;
    
    end if;
end process inorder_predecessor;


-- Reordering / Constructing tree --
-- This process completes tree construction, node insert and node delete operations by updating node registers and arrays. 
reorder_construct_tree: process(CLK)
begin

    if rising_edge (CLK) then

        -- Initializing tree
        if (initialize_tree = '1') then
        
            -- Initializing tree nodes array that holds node values 
            -- Initializing node child array that holds child indices of a node 
            for i in 0 to TREE_SIZE loop
                tree_nodes(i)   <= 0;
                node_child(i,0) <= 0;
                node_child(i,1) <= 0;
            end loop;
        
            -- Initializing index array that holds available indices 
            for i in 0 to TREE_SIZE-1 loop
                ind_array(i) <= i+1;
            end loop;
            ind_array_size  <= TREE_SIZE;           -- determining available index numbers 
            
            -- Assigning root index number for initialized tree
            root_ind        <= 1;
            
        end if;
        
        -- Constructing tree
        if (construct_tree = '1') then
        
            -- Constructing tree nodes array that holds node values 
            -- Constructing node child array that holds child indices of a node
            tree_nodes(ind_array(0))   <= in_node_val;
            node_child(ind_array(0),0) <= in_child_l_ind;
            node_child(ind_array(0),1) <= in_child_r_ind;
        
            -- Updating index array that holds available indices 
            for i in 0 to TREE_SIZE-2 loop
                ind_array(i) <= ind_array(i+1);
            end loop;
            ind_array(TREE_SIZE-1) <= 0;
            
            ind_array_size  <= ind_array_size - 1;  -- determining available index numbers 
            
        end if;
        
        -- Inserting a node
        if (insert_node = '1') then
        
            -- Inserting a node to left/right position
            if (insert_pst = '0') then  -- insert to left of the leaf node
            
                node_child(insert_ind,0)      <= ind_array(0); -- update inserted node's parent child info 
                tree_nodes(ind_array(0))      <= insert_val;
                node_child(ind_array(0),0)    <= 0;
                node_child(ind_array(0),1)    <= 0;
                
            else                        -- insert to right of the leaf node
                
                node_child(insert_ind,1)      <= ind_array(0); -- update inserted node's parent child info 
                tree_nodes(ind_array(0))      <= insert_val;
                node_child(ind_array(0),0)    <= 0;
                node_child(ind_array(0),1)    <= 0;
            
            end if;
            
            -- Updating index array that holds available indices 
            for i in 0 to TREE_SIZE-2 loop
                ind_array(i) <= ind_array(i+1);
            end loop;
            ind_array(TREE_SIZE-1)    <= 0;
            ind_array_size            <= ind_array_size - 1;    -- determining available index numbers   
                  
        end if;
        
        ---------------------------------------------------------------
        -- Deleting a node --------------------------------------------
        
        -- Node is a leaf
        if (delete_type_1 = '1') then
       
            -- delete node
            if (parent_l_r = '0') then
                node_child(parent_ind,0) <= 0;
            else
                node_child(parent_ind,1) <= 0;
            end if;
            node_child(node_ind,0) <= 0; 
            node_child(node_ind,1) <= 0; 
            tree_nodes(node_ind)   <= 0; 
            
            -- Updating index array that holds available indices 
            ind_array(ind_array_size)       <= node_ind;
            ind_array_size                  <= ind_array_size + 1; -- determining available index numbers 
               
        end if;
        
        -- Node has only right child
        if (delete_type_2 = '1') then
        
            -- Checking if node is root
            if (root_hit = '0') then
                
                -- Replacing node with it's child
                if (parent_l_r = '0') then
                    node_child(parent_ind,0) <= node_child(node_ind,1);
                else
                    node_child(parent_ind,1) <= node_child(node_ind,1);
                end if;
                
                -- Deleting node
                node_child(node_ind,0) <= 0; 
                node_child(node_ind,1) <= 0; 
                tree_nodes(node_ind)   <= 0; 
                
                -- Updating index array that holds available indices 
                ind_array(ind_array_size)       <= node_ind;
                ind_array_size                  <= ind_array_size + 1; -- determining available index numbers 
            
            else -- node is root
                -- Replacing node with it's child
                root_ind <= node_child(node_ind,1); 
                
                -- Deleting node
                node_child(node_ind,0) <= 0; 
                node_child(node_ind,1) <= 0; 
                tree_nodes(node_ind)   <= 0; 
                
                -- Updating index array that holds available indices 
                ind_array(ind_array_size)       <= node_ind;
                ind_array_size                  <= ind_array_size + 1; -- determining available index numbers 
            
            end if;
            
        end if;
        
        -- Node has only left child
        if (delete_type_3 = '1') then
        
            -- Checking if node is root
            if (root_hit = '0') then
                
                -- Replacing node with it's child
                if (parent_l_r = '0') then
                    node_child(parent_ind,0) <= node_child(node_ind,0);
                else
                    node_child(parent_ind,1) <= node_child(node_ind,0);
                end if;
                
                -- Deleting node
                node_child(node_ind,0) <= 0; 
                node_child(node_ind,1) <= 0; 
                tree_nodes(node_ind)   <= 0; 
                
                -- Updating index array that holds available indices 
                ind_array(ind_array_size)       <= node_ind;
                ind_array_size                  <= ind_array_size + 1; -- determining available index numbers 
            
            else -- node is root
                -- Replacing node with it's child
                root_ind <= node_child(node_ind,0);
                
                -- Deleting node
                node_child(node_ind,0) <= 0; 
                node_child(node_ind,1) <= 0; 
                tree_nodes(node_ind)   <= 0; 
                
                -- Updating index array that holds available indices 
                ind_array(ind_array_size)       <= node_ind;
                ind_array_size                  <= ind_array_size + 1; -- determining available index numbers 
            
            end if;
            
        end if;
        
        -- Node has left child and right child - inorder predecessor is the right child of the node 
        if (delete_type_4 = '1') then
        
            -- Checking if node is root
            if (root_hit = '0') then
            
                -- Replacing node with it's inorder predecessor
                if (parent_l_r = '0') then
                    node_child(parent_ind,0) <= pred_ind;
                else
                    node_child(parent_ind,1) <= pred_ind;
                end if;
                node_child(pred_ind,0) <= node_child(node_ind,0);
                
                 -- Deleting node
                node_child(node_ind,0) <= 0; -- optional
                node_child(node_ind,1) <= 0; -- optional
                tree_nodes(node_ind)   <= 0; -- optional
                
                -- Updating index array that holds available indices 
                ind_array(ind_array_size)       <= node_ind;
                ind_array_size                  <= ind_array_size + 1; -- determining available index numbers 
            
            else -- node is root
            
                -- Replacing node with it's child
                root_ind                <= pred_ind;
                node_child(pred_ind,0)  <= node_child(node_ind,0);
                
                -- Deleting node
                node_child(node_ind,0) <= 0; 
                node_child(node_ind,1) <= 0; 
                tree_nodes(node_ind)   <= 0; 
                
                -- Updating index array that holds available indices 
                ind_array(ind_array_size)       <= node_ind;
                ind_array_size                  <= ind_array_size + 1; -- determining available index numbers 
            
            end if;                    
            
        end if;
        
        -- Node has left child and right child
        if (delete_type_5 = '1') then
        
            -- Checking if node is root
            if (root_hit = '0') then
            
                -- Replacing node with it's inorder predecessor
                if (parent_l_r = '0') then
                    node_child(parent_ind,0) <= pred_ind;
                else
                    node_child(parent_ind,1) <= pred_ind;
                end if;
                node_child(pred_ind,0) <= node_child(node_ind,0);
                node_child(pred_ind,1) <= node_child(node_ind,1);
                
                
                -- Removing inorder predecessor
                node_child(pred_parent_ind,0) <= 0;
                
                 -- Deleting node
                node_child(node_ind,0) <= 0; 
                node_child(node_ind,1) <= 0; 
                tree_nodes(node_ind)   <= 0; 
                
                -- Updating index array that holds available indices 
                ind_array(ind_array_size)       <= node_ind;
                ind_array_size                  <= ind_array_size + 1; -- determining available index numbers 
            
            else -- node is root
            
                -- Replacing node with it's child
                root_ind                <= pred_ind;
                node_child(pred_ind,0)  <= node_child(node_ind,0);
                node_child(pred_ind,1)  <= node_child(node_ind,1);
                
                -- Removing inorder predecessor
                node_child(pred_parent_ind,0) <= 0;
                
                -- Deleting node
                node_child(node_ind,0) <= 0; 
                node_child(node_ind,1) <= 0; 
                tree_nodes(node_ind)   <= 0; 
                
                -- Updating index array that holds available indices 
                ind_array(ind_array_size)       <= node_ind;
                ind_array_size                  <= ind_array_size + 1; -- determining available index numbers 
            
            end if;                    
             
        end if;
  
    end if;  
end process reorder_construct_tree;


end behavioral;
