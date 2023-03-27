# environment description
The experimental topology is shown in the figure:

![](https://rancho333.github.io/pictures/questone2a_25G_topology.png)
<!--more-->

We only need add one ixia 100G port to topology, and set the line rate of 25 percent to test Questone2A 25G ports.
![](https://rancho333.github.io/pictures/questone2a_25G_ixia_topology.png)

For Questone2A, follow the below cmds to set up test enviorments.
```
vlan clear              	
vlan remove 1 pbm=ce       
vlan remove 1 pbm=xe 

vlan create 103 pbm=xe0,ce0 ubm=xe0,ce0; pvlan set xe0,ce0 103
vlan create 100 pbm=xe1,xe2 ubm=xe1,xe2; pvlan set xe1,xe2 100
vlan create 101 pbm=xe3,xe4 ubm=xe3,xe4; pvlan set xe3,xe4 101
vlan create 102 pbm=xe5,xe6 ubm=xe5,xe6; pvlan set xe5,xe6 102
vlan create 104 pbm=xe7,ce0 ubm=xe7,ce0; pvlan set xe7,ce0 104
```

We test three different(20,25,30) line rate speed, and expect no packets loss when line rate under 25 percent.

We use default preemphasis and differnet FEC setting to test line rate of 25G port.

## FEC fc

For fec mode of fc，ports status show as below picture.
![](https://rancho333.github.io/pictures/questone2a_25g_fec_fc.png)

### Line rate 20 percent

Just set line rate 20 percent on ixia like below picture.
![](https://rancho333.github.io/pictures/questone2a_line_rate_20.png)

Test results show as below picture and meet expectations.
![](https://rancho333.github.io/pictures/questone2a_line_rate_20_result.png)

### Line rate 25 percent
Test results show as below picture and meet expectations.
![](https://rancho333.github.io/pictures/questone2a_line_rate_25.png)

### Line rate 30 percent
Test results show as below picture and packets loss.
![](https://rancho333.github.io/pictures/questone2a_line_rate_30.png)

## Fec none
For fec mode of none, ports status show as below picture.
![](https://rancho333.github.io/pictures/questone2a_25_fec_none.png)

### Line rate 20 percent
For fec mode of none, ports status show as below picture.
![](https://rancho333.github.io/pictures/questone2a_line_rate_20_none.png)

### Line rate 25 percent
For fec mode of none, ports status show as below picture.
![](https://rancho333.github.io/pictures/questone2a_line_rate_25_none.png)

### Line rate 30 percent
Test results show as below picture and packets loss.
![](https://rancho333.github.io/pictures/questone2a_line_rate_30_none.png)
