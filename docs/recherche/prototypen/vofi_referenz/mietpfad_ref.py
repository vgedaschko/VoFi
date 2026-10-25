# Monatliche Mietpfad-Simulation: § 559-Umlage + § 558-Erhoehungen mit Kappung
R0=7.50; U=2.00; ovm0=9.20; g=0.025; k=0.15
months=range(-36,121)
R={m:R0 for m in range(-60,1)}
last558=-6
inc559={3:U}   # wirksam ab Monat 3
def ovm(m): return (ovm0 if m>=3 else 8.00)*(1+g)**(m/12)
log=[]
for m in range(1,121):
    r=R[m-1]
    if m in inc559: r+=inc559[m]
    if m-last558>=15:
        base=R.get(m-36,R0)
        s559=sum(v for t,v in inc559.items() if m-36<t<=m)
        cap=base*(1+k)+s559
        target=min(ovm(m),cap)
        if target>r+1e-9:
            r=target; last558=m; log.append((m,round(ovm(m),3),round(cap,3),round(r,3)))
    R[m]=r
for m in [0,3,12,24,36,48,60,84,120]:
    print(f"Monat {m:3d}: Miete {R[m]:.3f} EUR/m2, OVM_mod {ovm(m):.3f}")
print("558-Erhoehungen (Monat, OVM, Kappungsgrenze, neue Miete):",log)
