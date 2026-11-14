
import random, math, json

W, H = 1280.0, 768.0
DT = 0.1

def simulate(level, runs=30, tmax=40.0, n_enemies=10, enemy_hp=20.0, enemy_speed=80.0, player_speed=160.0, seed=42):
    # 档位
    if level == 1:
        dmg_per_tick, tick, interval, dur, size = 2.5, 0.5, 1.5, 5.0, 1.0
    else:  # L5
        dmg_per_tick, tick, interval, dur, size = 4.6, 0.5, 1.35, 6.0, 1.3
    radius = 64.0 * size
    rng = random.Random(seed)
    all_cov, all_poison_frac, all_ttk_poison, kills_by_poison, all_in_time = [], [], [], 0, []
    for run in range(runs):
        px, py = W/2, H/2
        enemies = []
        for i in range(n_enemies):
            side = rng.randint(0,3)
            if side==0: ex,ey = rng.uniform(0,W), 0.0
            elif side==1: ex,ey = rng.uniform(0,W), H
            elif side==2: ex,ey = 0.0, rng.uniform(0,H)
            else: ex,ey = W, rng.uniform(0,H)
            enemies.append({"x":ex,"y":ey,"hp":enemy_hp,"alive":True,"poison_dmg":0.0,"in_t":0.0,"life":0.0})
        clouds = []  # (x,y,age)
        fire_t = 0.0
        t = 0.0
        while t < tmax:
            t += DT
            # player kites: move away from nearest alive enemy, clamp to room
            alive = [e for e in enemies if e["alive"]]
            if not alive: break
            nx = min(alive, key=lambda e:(e["x"]-px)**2+(e["y"]-py)**2)
            dx, dy = px-nx["x"], py-nx["y"]
            d = math.hypot(dx,dy) or 1.0
            px = min(max(px + dx/d*player_speed*DT, 40), W-40)
            py = min(max(py + dy/d*player_speed*DT, 40), H-40)
            # fire cloud at nearest enemy to player
            fire_t += DT
            if fire_t >= interval:
                fire_t = 0.0
                if alive:
                    tgt = min(alive, key=lambda e:(e["x"]-px)**2+(e["y"]-py)**2)
                    clouds.append([tgt["x"], tgt["y"], 0.0])
                    if len(clouds) > 4: clouds.pop(0)  # cap 4, oldest dies
            # update clouds
            for c in clouds: c[2] += DT
            clouds = [c for c in clouds if c[2] < dur]
            # enemies walk toward player, take poison ticks
            for e in alive:
                e["life"] += DT
                dx, dy = px-e["x"], py-e["y"]
                d = math.hypot(dx,dy) or 1.0
                if d > 24:  # stop at contact range
                    e["x"] += dx/d*enemy_speed*DT
                    e["y"] += dy/d*enemy_speed*DT
                inside = any((e["x"]-c[0])**2+(e["y"]-c[1])**2 <= radius*radius for c in clouds)
                if inside:
                    e["in_t"] += DT
                    e["poison_dmg"] += dmg_per_tick * (DT/tick)
                    e["hp"] -= dmg_per_tick * (DT/tick)
                    if e["hp"] <= 0:
                        e["alive"] = False
                        kills_by_poison += 1
        n_alive = [e for e in enemies if e["alive"]]
        all_cov.append(sum(1 for e in enemies if e["in_t"]>0)/len(enemies))
        all_poison_frac.append(sum(e["in_t"] for e in enemies)/max(sum(e["life"] for e in enemies),0.01))
        all_in_time.append(sum(e["in_t"] for e in enemies)/len(enemies))
        # time to kill by poison alone (continuous): hp / (dps * in_frac)
        in_frac = sum(e["in_t"] for e in enemies)/max(sum(e["life"] for e in enemies),0.01)
        if in_frac > 0:
            all_ttk_poison.append(enemy_hp/( (dmg_per_tick/tick) * in_frac ))
    avg = lambda l: sum(l)/len(l) if l else 0
    return {
        "level": level, "radius": radius, "dps": dmg_per_tick/tick,
        "enemies_touched_by_cloud_%": round(avg(all_cov)*100,1),
        "enemy_lifetime_in_cloud_%": round(avg(all_poison_frac)*100,1),
        "avg_in_cloud_seconds_per_enemy": round(avg(all_in_time),2),
        "poison_solo_ttk_seconds": round(avg(all_ttk_poison),2) if all_ttk_poison else None,
        "kills_by_poison_alone_in_%ds_window" % int(tmax): kills_by_poison,
        "runs": runs,
    }

out = []
for lvl in (1, 5):
    out.append(simulate(lvl, enemy_hp=20.0))   # zombie/werewolf 档
    out.append(simulate(lvl, enemy_hp=12.0))   # vampire/bat 档
    out.append(simulate(lvl, enemy_hp=35.0, enemy_speed=70))  # elite_vampire 档
print(json.dumps(out, ensure_ascii=False, indent=1))
