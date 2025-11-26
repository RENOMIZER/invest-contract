// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {ERC20} from "./ERC20.sol";

contract Invest is ERC20("SOIN", "N$") {
    struct User {
        uint256 balance;
    }

    struct Project {
        uint256 balance;
        uint256 capital;
        uint256 goal;
        uint256 interest;
        address author;
        uint256 investorsCount;
        address[] investors;
        Status status;
    }

    enum Status {
        Collecting,
        Paying,
        Finilizing,
        Closed
    }

    mapping(address => bool) private isRegistred;
    mapping(address => User) public users;

    uint256 public projectCount = 0;
    mapping(uint256 => bool) private doesExist;
    mapping(uint256 => Project) public projects;
    mapping(uint256 => mapping(address => uint256)) public projectsInvestments;

    address public admin;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only for admin");
        _;
    }

    modifier onlyUser() {
        require(msg.sender != admin, "Admin can't be a user");
        _;
    }

    constructor() {
        admin = msg.sender;

        _mint(admin, 50000 * 10**18);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function balanceOfWallet(address wallet) public view returns (uint256) {
        return balanceOf(wallet);
    }

    function registerUser() onlyUser public {
        require(!isRegistred[msg.sender], "Already registred");
        
        isRegistred[msg.sender] = true;
        users[msg.sender] = User(0);
    }

    function giveTokens(address _user, uint256 _amount) onlyAdmin public {
        require(isRegistred[_user], "User not registred");
        
        transfer(_user, _amount);
        users[_user].balance += _amount;
    }

    function takeTokens(address _user, uint256 _amount) onlyAdmin public {
        require(isRegistred[_user], "User not registred");
        
        transferFrom(_user, admin, _amount);
        users[_user].balance -= _amount;
    }

    function createProject(uint256 _goal, uint256 _interest) onlyUser public returns(uint256) {
        require(isRegistred[msg.sender], "User not registred");

        uint256 projectId = projectCount;
        projects[projectId] = Project(0, 0, _goal, _interest, msg.sender, 0, new address[](0), Status.Collecting);
        doesExist[projectId] = true;
        projectCount++;

        return projectId;
    }

    function investInProject(uint256 _projectId, uint256 _amount) onlyUser public {
        require(isRegistred[msg.sender], "User not registred");
        require(users[msg.sender].balance >= _amount, "User's balance is too low");
        require(doesExist[_projectId], "Project doesn't exist");
        require(projects[_projectId].status == Status.Collecting, "Project doesn't accept investments anymore");
        require(projects[_projectId].author != msg.sender, "Can't invest in own project");

        transfer(admin, _amount);
        users[msg.sender].balance -= _amount;

        if (projectsInvestments[_projectId][msg.sender] == 0) {
            projects[_projectId].investors.push(msg.sender);
            projects[_projectId].investorsCount += 1;
        } 
        
        projects[_projectId].balance = projects[_projectId].capital += _amount;
        projectsInvestments[_projectId][msg.sender] += _amount;

        if (projects[_projectId].balance >= projects[_projectId].goal) {
            projects[_projectId].status = Status.Paying;
        }
    }

    function issueTokens(uint256 _projectId, uint256 _amount) onlyAdmin public {
        require(doesExist[_projectId], "Project doesn't exist");
        require(projects[_projectId].status == Status.Paying, "Project's goal isn't reached yet");
        require(projects[_projectId].balance >= _amount, "Project's balance is too low");

        transfer(projects[_projectId].author, _amount);
        users[projects[_projectId].author].balance += _amount;
        projects[_projectId].balance -= _amount;
    }

    function payInvestors(uint256 _projectId, uint256 _amount) onlyUser public {
        require(isRegistred[msg.sender], "User not registred");
        require(users[msg.sender].balance >= _amount, "User's balance is too low");
        require(doesExist[_projectId], "Project doesn't exist");
        require(projects[_projectId].status == Status.Paying, "Project isn't Paying tokens");

        for (uint256 i = 0; i < projects[_projectId].investorsCount; i++) {
            address investor = projects[_projectId].investors[i];
            uint256 contribution = projectsInvestments[_projectId][investor];
            uint256 capital =  projects[_projectId].capital;

            uint256 scaledProportion = (contribution * 1e18) / capital;
            uint256 baseIncomeShare = (scaledProportion * _amount) / 1e18;
            uint256 interestPayment = baseIncomeShare * projects[_projectId].interest / 100;

            users[msg.sender].balance -= interestPayment;
            users[investor].balance += interestPayment;
            transfer(investor, interestPayment);

            projects[_projectId].balance += _amount - interestPayment;
            transfer(admin, _amount - interestPayment);

            if (projects[_projectId].balance >= capital) {
                projects[_projectId].status = Status.Finilizing;
            }
        }
    }

    function closeProject(uint256 _projectId) onlyAdmin public {
        for (uint256 i = 0; i < projects[_projectId].investorsCount; i++) {
            address investor = projects[_projectId].investors[i];
            uint256 contribution = projectsInvestments[_projectId][investor];
            uint256 capital =  projects[_projectId].capital;

            uint256 scaledProportion = (contribution * 1e18) / capital;

            projects[_projectId].balance -= scaledProportion;

            users[investor].balance += scaledProportion;
            transfer(investor, scaledProportion);
        }

        transfer(projects[_projectId].author, projects[_projectId].balance);
        projects[_projectId].status = Status.Closed;
    }
}